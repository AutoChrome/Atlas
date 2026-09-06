# Re-importing a file into a chart that already has tables on it: diff the
# freshly-parsed { tables:, table_order:, pending_fks: } against what the
# chart already has, and apply the difference — additive only, nothing is
# ever deleted here (a table/column/relationship that exists on the chart
# but isn't in the new file is left alone and just surfaced for awareness).
#
# Matching is case-insensitive by name ("Users" and "users" are the same
# table), but any other difference in the name is treated as a genuinely
# different thing — "users" and "users_v2" create a new table rather than
# updating the existing one.
module ChartImportSync
  TablePlan = Struct.new(:name, :new?, :table, :column_plans, :index_plans, :unmatched_columns, :unmatched_indexes, keyword_init: true)
  ColumnPlan = Struct.new(:name, :new?, :column, :changes, :attrs, keyword_init: true)
  IndexPlan = Struct.new(:name, :new?, :index, :changes, :attrs, keyword_init: true)
  RelationshipPlan = Struct.new(:new?, :relationship, :from_label, :to_label, :changes, :attrs, keyword_init: true)
  Diff = Struct.new(:table_plans, :relationship_plans, :unmatched_tables, keyword_init: true)

  class << self
    # Read-only — computes what an apply! would do, for the preview page.
    def diff(chart:, tables:, table_order:, pending_fks:)
      existing_by_name = chart.chart_tables.includes(:chart_columns, :chart_indices).index_by { |t| t.name.downcase }
      matched_names = []

      table_plans = table_order.map do |name|
        existing = existing_by_name[name.downcase]
        matched_names << name.downcase if existing
        table_plan(name, existing, tables[name])
      end

      unmatched_tables = existing_by_name.reject { |downcased, _| matched_names.include?(downcased) }.values
      relationship_plans = relationship_plans(table_plans, pending_fks)

      Diff.new(table_plans: table_plans, relationship_plans: relationship_plans, unmatched_tables: unmatched_tables)
    end

    # Actually persists the changes described by a diff computed the same
    # way — re-resolved against the chart's current state rather than the
    # exact objects from an earlier `diff` call, so this is safe to run
    # even if some time has passed since the file was uploaded.
    def apply!(chart:, tables:, table_order:, pending_fks:)
      ActiveRecord::Base.transaction do
        table_order.each_with_index do |name, index|
          table = chart.chart_tables.find { |t| t.name.casecmp?(name) } ||
                  chart.chart_tables.create!(name: name, position_x: (index % 4) * 320, position_y: (index / 4) * 360)

          apply_columns!(table, tables[name][:columns])
          apply_indexes!(table, tables[name][:indexes])
        end

        apply_relationships!(chart, pending_fks)
      end
    end

    private
      def table_plan(name, existing, data)
        column_plans, unmatched_columns = column_plans(existing, data[:columns])
        index_plans, unmatched_indexes = index_plans(existing, data[:indexes])

        TablePlan.new(
          name: name, new?: existing.nil?, table: existing,
          column_plans: column_plans, index_plans: index_plans,
          unmatched_columns: unmatched_columns, unmatched_indexes: unmatched_indexes
        )
      end

      def column_plans(existing_table, parsed_columns)
        existing_by_name = existing_table ? existing_table.chart_columns.index_by { |c| c.name.downcase } : {}
        matched = []

        plans = parsed_columns.map do |col|
          existing = existing_by_name[col[:name].downcase]
          matched << col[:name].downcase if existing

          attrs = {
            data_type: col[:data_type], nullable: col.fetch(:nullable, true),
            primary_key: col[:primary_key] || false, unique: col[:unique] || false,
            default_value: col[:default_value]
          }
          changes = existing ? changed_attrs(existing, attrs) : {}

          ColumnPlan.new(name: col[:name], new?: existing.nil?, column: existing, changes: changes, attrs: attrs)
        end

        [ plans, existing_by_name.reject { |downcased, _| matched.include?(downcased) }.values ]
      end

      def index_plans(existing_table, parsed_indexes)
        existing_by_name = existing_table ? existing_table.chart_indices.index_by { |i| i.name.downcase } : {}
        matched = []

        plans = parsed_indexes.map do |idx|
          existing = existing_by_name[idx[:name].downcase]
          matched << idx[:name].downcase if existing

          attrs = { unique: idx[:unique] || false, columns: idx[:columns].join(", ") }
          changes = existing ? changed_attrs(existing, attrs) : {}

          IndexPlan.new(name: idx[:name], new?: existing.nil?, index: existing, changes: changes, attrs: attrs)
        end

        [ plans, existing_by_name.reject { |downcased, _| matched.include?(downcased) }.values ]
      end

      def relationship_plans(table_plans, pending_fks)
        table_plan_by_name = table_plans.index_by { |tp| tp.name.downcase }

        pending_fks.filter_map do |fk|
          from_plan = table_plan_by_name[fk[:from_table].to_s.downcase]
          to_plan = table_plan_by_name[fk[:to_table].to_s.downcase]
          next unless from_plan && to_plan

          from_col = from_plan.column_plans.find { |cp| cp.name.downcase == fk[:from_column].to_s.downcase }
          to_col = to_plan.column_plans.find { |cp| cp.name.downcase == fk[:to_column].to_s.downcase }
          next unless from_col && to_col

          existing = if from_col.column && to_col.column
            ChartRelationship.find_by(from_chart_column_id: from_col.column.id, to_chart_column_id: to_col.column.id)
          end

          attrs = { on_delete: fk[:on_delete], on_update: fk[:on_update] }
          changes = existing ? changed_attrs(existing, attrs) : {}

          RelationshipPlan.new(
            new?: existing.nil?, relationship: existing,
            from_label: "#{from_plan.name}.#{from_col.name}", to_label: "#{to_plan.name}.#{to_col.name}",
            changes: changes, attrs: attrs
          )
        end
      end

      def changed_attrs(record, attrs)
        attrs.each_with_object({}) do |(field, new_value), changes|
          old_value = record.public_send(field)
          changes[field] = [ old_value, new_value ] if old_value != new_value
        end
      end

      def apply_columns!(table, parsed_columns)
        existing_by_name = table.chart_columns.index_by { |c| c.name.downcase }
        next_position = table.chart_columns.maximum(:position).to_i + 1

        parsed_columns.each do |col|
          attrs = {
            data_type: col[:data_type], nullable: col.fetch(:nullable, true),
            primary_key: col[:primary_key] || false, unique: col[:unique] || false,
            default_value: col[:default_value]
          }

          if (existing = existing_by_name[col[:name].downcase])
            existing.update!(attrs) if changed_attrs(existing, attrs).any?
          else
            table.chart_columns.create!(attrs.merge(name: col[:name], position: next_position))
            next_position += 1
          end
        end
      end

      def apply_indexes!(table, parsed_indexes)
        existing_by_name = table.chart_indices.index_by { |i| i.name.downcase }

        parsed_indexes.each do |idx|
          attrs = { unique: idx[:unique] || false, columns: idx[:columns].join(", ") }

          if (existing = existing_by_name[idx[:name].downcase])
            existing.update!(attrs) if changed_attrs(existing, attrs).any?
          else
            table.chart_indices.create!(attrs.merge(name: idx[:name]))
          end
        end
      end

      # Resolved fresh by name against the chart's current state (rather
      # than reusing plan objects) so this works regardless of what was
      # just created above in this same pass.
      def apply_relationships!(chart, pending_fks)
        chart.reload
        tables_by_name = chart.chart_tables.includes(:chart_columns).index_by { |t| t.name.downcase }

        pending_fks.each do |fk|
          from_table = tables_by_name[fk[:from_table].to_s.downcase]
          to_table = tables_by_name[fk[:to_table].to_s.downcase]
          from_col = from_table&.chart_columns&.find { |c| c.name.casecmp?(fk[:from_column].to_s) }
          to_col = to_table&.chart_columns&.find { |c| c.name.casecmp?(fk[:to_column].to_s) }
          next unless from_col && to_col

          attrs = { on_delete: fk[:on_delete], on_update: fk[:on_update] }
          existing = ChartRelationship.find_by(from_chart_column_id: from_col.id, to_chart_column_id: to_col.id)

          if existing
            existing.update!(attrs) if changed_attrs(existing, attrs).any?
          else
            chart.chart_relationships.create!(attrs.merge(from_chart_column: from_col, to_chart_column: to_col))
          end
        end
      end
  end
end
