# Best-effort import of a Rails db/schema.rb dump into a Chart. Many Rails
# apps already have this file sitting in their repo — no pg_dump/mysqldump
# export step needed, just upload it directly.
#
# SECURITY: db/schema.rb is a real, executable Ruby file (it's literally
# `eval`'d by `rails db:schema:load`). This parser NEVER evaluates, loads,
# instance_evals, or otherwise executes any part of an uploaded file — it
# only reads it as plain text and pattern-matches the handful of DSL method
# calls schema.rb dumps are made of (`create_table`, `t.<type>`, `t.index`,
# `add_foreign_key`, `add_index`). Anything that doesn't match one of those
# shapes is simply ignored, never executed. Do not "simplify" this by
# reaching for `eval`/`instance_eval` later — an uploaded file is untrusted
# input from whoever has chart-create access, and evaluating it would be
# arbitrary code execution.
module SchemaRbParser
  Result = ChartImportBuilder::Result

  CREATE_TABLE_RE = /\Acreate_table\s+"([^"]+)"(?:\s*,\s*(.*))?\z/
  COLUMN_LINE_RE = /\At\.(\w+)\s+"([^"]+)"(?:\s*,\s*(.*))?\z/
  INDEX_LINE_RE = /\At\.index\s+(\[[^\]]*\]|"[^"]+")(?:\s*,\s*(.*))?\z/
  ADD_FOREIGN_KEY_RE = /\Aadd_foreign_key\s+"([^"]+)"\s*,\s*"([^"]+)"(?:\s*,\s*(.*))?\z/
  ADD_INDEX_RE = /\Aadd_index\s+"([^"]+)"\s*,\s*(\[[^\]]*\]|"[^"]+")(?:\s*,\s*(.*))?\z/
  NON_COLUMN_TYPES = %w[index foreign_key check_constraint].freeze

  class << self
    # Pure parsing — no database access. See SqlSchemaParser.parse for the
    # shared shape this returns and why it's split out from `import`.
    def parse(ruby:)
      tables = {}
      table_order = []
      pending_fks = []
      warnings = []
      current_table = nil

      ruby.each_line do |raw_line|
        line = strip_line_comment(raw_line).strip
        next if line.empty?

        # A create_table line's trailing " do |t|" isn't part of its
        # options — drop it before parsing what follows the table name.
        line = line.sub(/\s*do\s*\|[^|]*\|\s*\z/, "")

        if (m = line.match(CREATE_TABLE_RE))
          name = m[1]
          tables[name] ||= { columns: [], indexes: [], notes: [] }
          table_order << name unless table_order.include?(name)
          current_table = name

          options = parse_ruby_options(m[2])
          if (pk = implicit_primary_key(options))
            tables[name][:columns] << pk
          end
        elsif current_table && line == "end"
          current_table = nil
        elsif current_table && (m = line.match(INDEX_LINE_RE))
          parse_index_line(m, tables[current_table])
        elsif current_table && (m = line.match(COLUMN_LINE_RE)) && !NON_COLUMN_TYPES.include?(m[1])
          parse_column_line(m, tables[current_table], pending_fks, current_table)
        elsif (m = line.match(ADD_FOREIGN_KEY_RE))
          parse_add_foreign_key(m, pending_fks)
        elsif (m = line.match(ADD_INDEX_RE))
          parse_add_index(m, tables, warnings)
        end
      end

      { tables: tables, table_order: table_order, pending_fks: pending_fks, warnings: warnings }
    end

    def import(ruby:, area:, title:)
      parsed = parse(ruby: ruby)
      ChartImportBuilder.build(area: area, title: title, **parsed)
    rescue => e
      Result.new(chart: nil, warnings: [ "Import failed: #{e.message}" ], tables_count: 0)
    end

    private
      def strip_line_comment(line)
        # A naive `line.split("#").first` would break on a `#` inside a
        # quoted default value — walk it the same string-literal-aware way
        # SqlSchemaParser's splitter does, just looking for "#" instead of ",".
        in_string = false
        line.each_char.with_index do |char, i|
          if char == '"' && line[i - 1] != "\\"
            in_string = !in_string
          elsif char == "#" && !in_string
            return line[0...i]
          end
        end
        line
      end

      def implicit_primary_key(options)
        return nil if options[:id] == false

        name = options[:primary_key].is_a?(String) ? options[:primary_key] : "id"
        type = options[:id].is_a?(String) ? options[:id] : "bigint"
        { name: name, data_type: type, nullable: false, primary_key: true, unique: false, default_value: nil }
      end

      def parse_column_line(match, table, pending_fks, table_name)
        type = match[1]
        name = match[2]
        options = parse_ruby_options(match[3])

        table[:columns] << {
          name: name,
          data_type: type,
          nullable: options[:null] != false,
          primary_key: false,
          unique: false,
          default_value: options[:default]&.to_s
        }
      end

      def parse_index_line(match, table)
        columns = columns_from_ruby_array_or_string(match[1])
        options = parse_ruby_options(match[2])

        if columns.size == 1 && options[:unique] == true
          column = table[:columns].find { |c| c[:name].casecmp?(columns.first) }
          column[:unique] = true if column
        end

        table[:indexes] << {
          name: options[:name] || "index_#{columns.join('_')}",
          unique: options[:unique] == true,
          columns: columns
        }
      end

      def parse_add_foreign_key(match, pending_fks)
        from_table = match[1]
        to_table = match[2]
        options = parse_ruby_options(match[3])

        pending_fks << {
          from_table: from_table,
          from_column: options[:column] || "#{to_table.singularize}_id",
          to_table: to_table,
          to_column: options[:primary_key] || "id",
          on_delete: options[:on_delete],
          on_update: options[:on_update]
        }
      end

      def parse_add_index(match, tables, warnings)
        table_name = match[1]
        table = tables[table_name]
        return warnings << "Skipped an index on unknown table \"#{table_name}\"." unless table

        columns = columns_from_ruby_array_or_string(match[2])
        options = parse_ruby_options(match[3])
        table[:indexes] << { name: options[:name] || "index_#{table_name}_#{columns.join('_')}", unique: options[:unique] == true, columns: columns }
      end

      def columns_from_ruby_array_or_string(token)
        if token.start_with?("[")
          token[1..-2].split(",").map { |c| unquote(c) }
        else
          [ unquote(token) ]
        end
      end

      # Parses a trailing Ruby keyword-argument list (e.g. `null: false,
      # default: "active", unique: true, on_delete: :cascade`) into a Hash.
      # Reuses SqlSchemaParser's string-literal-aware comma splitter so a
      # quoted default containing a comma isn't torn apart.
      def parse_ruby_options(str)
        return {} if str.blank?

        SqlSchemaParser::StatementSplitter.split_on(str, ",", quote: '"').each_with_object({}) do |item, hash|
          if (m = item.strip.match(/\A(\w+):\s*(.*)\z/m))
            hash[m[1].to_sym] = parse_ruby_value(m[2].strip)
          end
        end
      end

      def parse_ruby_value(token)
        case token
        when /\A"((?:[^"\\]|\\.)*)"\z/m then $1.gsub('\\"', '"')
        when "true" then true
        when "false" then false
        when "nil" then nil
        when /\A:(\w+)\z/ then $1
        else token
        end
      end

      def unquote(token)
        token.to_s.strip.gsub(/\A"|"\z/, "")
      end
  end
end
