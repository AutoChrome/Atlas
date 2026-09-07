# Older, hand-rolled schemas (especially MySQL dumps, and MyISAM tables in
# particular, which can't hold FK constraints at all) frequently have no
# `add_foreign_key`/`REFERENCES` anywhere — the only signal that a column
# like "cst_id" points at another table is that some table's *primary key*
# is also named "cst_id". This is a best-effort second pass over the
# already-parsed tables that turns that naming convention into relationships,
# run after (and never overriding) whatever explicit FKs the dump declared.
#
# It only ever acts when a column's name matches exactly one table's primary
# key — ambiguous matches (two tables sharing a primary key name, which does
# happen — see the `manual_key` note below) are surfaced as a warning instead
# of guessed at, since a wrong relationship is more misleading than a missing
# one.
module ForeignKeyInference
  # "id" alone is too generic to mean anything by naming convention — plenty
  # of unrelated tables have a plain, non-primary "id" column.
  GENERIC_PK_NAMES = %w[id].freeze

  class << self
    # `tables` is the { "table_name" => { columns:, indexes:, notes: } }
    # shape every parser produces, where a primary key column may carry a
    # `manual_key: true` hint (currently only SchemaRbParser sets this) —
    # meaning its value isn't independently generated (e.g. schema.rb's
    # `id: { ..., default: nil }`), the standard sign of a table that shares
    # another table's primary key rather than owning that identity itself
    # (a 1:1 "annotation"/extension table). When a primary key name is
    # ambiguous, such a table is passed over in favor of a candidate that
    # does generate its own key, since the extension table is never what a
    # column elsewhere actually means to point at.
    def infer(tables:, pending_fks:)
      pk_owners = Hash.new { |h, k| h[k] = [] }
      tables.each do |table_name, data|
        pk = data[:columns].find { |c| c[:primary_key] }
        next unless pk
        next if GENERIC_PK_NAMES.include?(pk[:name].downcase)

        pk_owners[pk[:name].downcase] << { table: table_name, manual_key: !!pk[:manual_key] }
      end

      explicit_fk_columns = pending_fks.each_with_object(Set.new) do |fk, set|
        set << [ fk[:from_table].to_s.downcase, fk[:from_column].to_s.downcase ]
      end

      inferred = []
      ambiguous = Hash.new { |h, k| h[k] = [] }

      tables.each do |table_name, data|
        data[:columns].each do |col|
          next if col[:primary_key]

          candidates = pk_owners[col[:name].downcase]
          next if candidates.empty?
          next if explicit_fk_columns.include?([ table_name.downcase, col[:name].downcase ])
          next if candidates.size == 1 && candidates.first[:table].casecmp?(table_name)

          resolved = candidates.reject { |c| c[:manual_key] }
          resolved = candidates if resolved.empty?

          if resolved.size == 1
            inferred << {
              from_table: table_name, from_column: col[:name],
              to_table: resolved.first[:table], to_column: col[:name],
              on_delete: nil, on_update: nil
            }
          else
            ambiguous[[ col[:name], resolved.map { |c| c[:table] } ]] << "#{table_name}.#{col[:name]}"
          end
        end
      end

      warnings = ambiguous.map do |(column_name, candidate_tables), occurrences|
        "#{occurrences.size} column#{'s' if occurrences.size != 1} named \"#{column_name}\" could reference " \
          "either #{candidate_tables.join(' or ')} (same primary key name on both) — add the relationship " \
          "manually if it's meant to point at one of them."
      end

      { pending_fks: pending_fks + inferred, warnings: warnings }
    end
  end
end
