# Shared "turn parsed tables/pending_fks into real Chart records" step for
# every schema importer (SqlSchemaParser, SchemaRbParser, ...). Each parser
# is responsible only for producing the same plain-data shape —
#   tables: { "name" => { columns: [...], indexes: [...], notes: [...] } }
#   table_order: ["name", ...]  (creation order, used for the grid layout)
#   pending_fks: [{ from_table:, from_column:, to_table:, to_column:, on_delete:, on_update: }]
# — however it needs to for its own format; this is the one place that
# turns that into Chart/ChartTable/ChartColumn/ChartRelationship/ChartIndex
# rows, so a fix here (or to the auto-layout) benefits every importer at once.
module ChartImportBuilder
  Result = Struct.new(:chart, :warnings, :tables_count, keyword_init: true)

  def self.build(area:, title:, tables:, table_order:, pending_fks:, warnings:)
    if table_order.empty?
      return Result.new(chart: nil, warnings: warnings.presence || [ "No tables were found in that file." ], tables_count: 0)
    end

    chart = ActiveRecord::Base.transaction do
      chart = area.charts.create!(title: title)
      columns_by_table = {}

      table_order.each_with_index do |name, index|
        data = tables[name]
        chart_table = chart.chart_tables.create!(
          name: name,
          position_x: (index % 4) * 320,
          position_y: (index / 4) * 360,
          notes: data[:notes].join("\n\n").presence
        )

        columns_by_table[name] = {}
        data[:columns].each_with_index do |col, position|
          columns_by_table[name][col[:name].downcase] = chart_table.chart_columns.create!(
            name: col[:name],
            data_type: col[:data_type],
            position: position,
            primary_key: col[:primary_key] || false,
            nullable: col.fetch(:nullable, true),
            unique: col[:unique] || false,
            default_value: col[:default_value]
          )
        end

        data[:indexes].each do |idx|
          chart_table.chart_indices.create!(name: idx[:name], unique: idx[:unique] || false, columns: idx[:columns].join(", "))
        end
      end

      pending_fks.each do |fk|
        from_col = columns_by_table.dig(fk[:from_table], fk[:from_column]&.downcase)
        to_col = columns_by_table.dig(fk[:to_table], fk[:to_column]&.downcase)

        if from_col && to_col
          chart.chart_relationships.create!(
            from_chart_column: from_col, to_chart_column: to_col,
            on_delete: fk[:on_delete], on_update: fk[:on_update]
          )
        else
          warnings << "Skipped a foreign key referencing an unknown table/column " \
                      "(#{fk[:from_table]}.#{fk[:from_column]} -> #{fk[:to_table]}.#{fk[:to_column]})."
        end
      end

      chart
    end

    Result.new(chart: chart, warnings: warnings, tables_count: table_order.size)
  rescue => e
    Result.new(chart: nil, warnings: [ "Import failed: #{e.message}" ], tables_count: 0)
  end
end
