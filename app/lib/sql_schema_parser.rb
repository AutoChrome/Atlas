# Best-effort import of a schema-only SQL dump into a Chart. This is NOT a
# full ANSI SQL parser — it recognizes the statement shapes that matter for
# real-world pg_dump/mysqldump/sqlite3 output (CREATE TABLE, ALTER TABLE ADD
# CONSTRAINT, CREATE INDEX) and silently skips or warns about anything else
# (views, triggers, procedures, structural CHECK parsing, multiple schemas,
# dollar-quoted bodies). The chart's whiteboard is the fix-up safety net for
# anything this gets wrong.
module SqlSchemaParser
  Result = ChartImportBuilder::Result

  IDENTIFIER_SRC = %q{(?:"[^"]+"|`[^`]+`|[A-Za-z_][\w$]*)}
  CREATE_TABLE_RE = /\ACREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?<name>#{IDENTIFIER_SRC}(?:\.#{IDENTIFIER_SRC})?)\s*\(/i
  ALTER_TABLE_RE = /\AALTER\s+TABLE\s+(?:ONLY\s+)?(?<table>#{IDENTIFIER_SRC}(?:\.#{IDENTIFIER_SRC})?)\s+ADD\s+CONSTRAINT\s+#{IDENTIFIER_SRC}\s+(?<rest>.*)\z/im
  CREATE_INDEX_RE = /\ACREATE\s+(?<unique>UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(?<name>#{IDENTIFIER_SRC})?\s*ON\s+(?<table>#{IDENTIFIER_SRC}(?:\.#{IDENTIFIER_SRC})?)\s*(?:USING\s+\w+\s*)?\((?<columns>[^)]*)\)/im
  # An inline table-level constraint (whether inside CREATE TABLE's body or
  # a top-level ALTER TABLE ADD CONSTRAINT) is very often given a name first
  # ("CONSTRAINT fk_orders_user FOREIGN KEY ...") — both Postgres and MySQL
  # dumps do this routinely, so the name prefix has to be optional here.
  OPTIONAL_CONSTRAINT_NAME_SRC = %Q{(?:CONSTRAINT\\s+#{IDENTIFIER_SRC}\\s+)?}
  FOREIGN_KEY_RE = /\A#{OPTIONAL_CONSTRAINT_NAME_SRC}FOREIGN\s+KEY\s*\((?<from>[^)]*)\)\s*REFERENCES\s+(?<table>#{IDENTIFIER_SRC}(?:\.#{IDENTIFIER_SRC})?)\s*\((?<to>[^)]*)\)(?<tail>.*)\z/im
  NOT_CONSTRAINT_START_RE = /\A(?:PRIMARY\s+KEY\s*\(|FOREIGN\s+KEY\s*\(|UNIQUE\s+KEY\s+|UNIQUE\s+INDEX\s+|UNIQUE\s*\(|CONSTRAINT\s+|CHECK\s*\(|KEY\s+|INDEX\s+)/i

  # Splits a full dump into top-level statements/comma-separated items,
  # tracking parenthesis/brace nesting AND single-quoted string literals so
  # `NUMERIC(10,2)`, `DEFAULT 'Smith, John'`, and a Ruby hash-literal option
  # like `id: { type: :integer, unsigned: true }` don't get split apart.
  module StatementSplitter
    def self.statements(sql)
      split_on(strip_comments(sql), ";").map(&:strip).reject(&:empty?)
    end

    def self.strip_comments(sql)
      sql.gsub(/--[^\n]*/, "").gsub(%r{/\*.*?\*/}m, "")
    end

    # `quote:` defaults to "'" for SQL string literals; SchemaRbParser passes
    # "\"" to split Ruby keyword-argument lists, which quote with double
    # quotes instead (e.g. `default: "Hi, there"`).
    def self.split_on(text, separator, quote: "'")
      depth = 0
      in_string = false
      current = +""
      result = []
      i = 0

      while i < text.length
        char = text[i]

        if in_string
          if char == "\\" && !text[i + 1].nil?
            # Backslash-escaped char (Ruby's `\"` inside a schema.rb default,
            # e.g.) — consume both chars as a literal, not a toggle.
            current << char << text[i + 1]
            i += 2
            next
          elsif char == quote && text[i + 1] == quote
            current << (quote * 2)
            i += 2
            next
          elsif char == quote
            in_string = false
          end
          current << char
          i += 1
          next
        end

        case char
        when quote then in_string = true; current << char
        when "(", "{" then depth += 1; current << char
        when ")", "}" then depth -= 1; current << char
        when separator
          if depth.zero?
            result << current
            current = +""
          else
            current << char
          end
        else
          current << char
        end
        i += 1
      end

      result << current
      result
    end

    # Finds the index of the "(" that matches the one at `open_index`.
    # Needed because a naive regex can't tell CREATE TABLE's real closing
    # paren apart from one inside `NUMERIC(10,2)`, and because MySQL dumps
    # commonly append trailing table options after the real close paren
    # (`) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;`) that must be discarded
    # rather than misparsed as another column.
    def self.matching_paren_index(text, open_index)
      depth = 0
      in_string = false
      i = open_index
      while i < text.length
        char = text[i]
        if in_string
          if char == "'" && text[i + 1] == "'"
            i += 2
            next
          elsif char == "'"
            in_string = false
          end
        elsif char == "'"
          in_string = true
        elsif char == "("
          depth += 1
        elsif char == ")"
          depth -= 1
          return i if depth.zero?
        end
        i += 1
      end
      nil
    end
  end

  class << self
    # Pure parsing — no database access. Returns the plain-data shape every
    # importer produces: { tables:, table_order:, pending_fks:, warnings: }.
    # Used both by `import` (create a brand-new chart) and by the "update an
    # existing chart" flow (ChartImportSync), which diffs this against what's
    # already there instead of creating fresh records.
    def parse(sql:)
      statements = StatementSplitter.statements(sql)
      warnings = []
      tables = {}
      table_order = []
      pending_fks = []

      statements.each do |stmt|
        case stmt
        when CREATE_TABLE_RE
          parse_create_table(stmt, tables, table_order, pending_fks, warnings)
        when ALTER_TABLE_RE
          parse_alter_table(stmt, tables, pending_fks, warnings)
        when CREATE_INDEX_RE
          parse_create_index(stmt, tables, warnings)
        end
      end

      inference = ForeignKeyInference.infer(tables: tables, pending_fks: pending_fks)
      { tables: tables, table_order: table_order, pending_fks: inference[:pending_fks], warnings: warnings + inference[:warnings] }
    end

    def import(sql:, area:, title:)
      parsed = parse(sql: sql)
      ChartImportBuilder.build(area: area, title: title, **parsed)
    rescue => e
      Result.new(chart: nil, warnings: [ "Import failed: #{e.message}" ], tables_count: 0)
    end

    private
      def parse_create_table(stmt, tables, table_order, pending_fks, warnings)
        match = stmt.match(CREATE_TABLE_RE)
        return warnings << "Couldn't parse a CREATE TABLE statement." unless match

        name = table_name_from(match[:name])
        open_paren = match.end(0) - 1
        close_paren = StatementSplitter.matching_paren_index(stmt, open_paren)
        return warnings << "Couldn't find the closing parenthesis for CREATE TABLE #{name}." unless close_paren

        body = stmt[(open_paren + 1)...close_paren]
        items = StatementSplitter.split_on(body, ",").map(&:strip).reject(&:empty?)

        tables[name] ||= { columns: [], indexes: [], notes: [] }
        table_order << name unless table_order.include?(name)
        table = tables[name]

        column_items, constraint_items = items.partition { |item| !item.match?(NOT_CONSTRAINT_START_RE) }
        column_items.each { |item| parse_column_definition(item, table, pending_fks, name) }
        constraint_items.each { |item| apply_table_constraint(item, table, pending_fks, name, warnings) }
      end

      def parse_alter_table(stmt, tables, pending_fks, warnings)
        match = stmt.match(ALTER_TABLE_RE)
        return unless match

        table_name = table_name_from(match[:table])
        apply_table_constraint(match[:rest], tables[table_name], pending_fks, table_name, warnings)
      end

      def parse_create_index(stmt, tables, warnings)
        match = stmt.match(CREATE_INDEX_RE)
        return warnings << "Couldn't parse a CREATE INDEX statement." unless match

        table_name = table_name_from(match[:table])
        table = tables[table_name]
        return warnings << "Skipped an index on unknown table \"#{table_name}\"." unless table

        columns = columns_from_list(match[:columns])
        name = match[:name] ? unquote(match[:name]) : "index_#{table_name}_#{columns.join('_')}"
        table[:indexes] << { name: name, unique: !match[:unique].nil?, columns: columns }
      end

      def apply_table_constraint(item, table, pending_fks, table_name, warnings)
        return if table.nil?

        case item
        when /\A#{OPTIONAL_CONSTRAINT_NAME_SRC}PRIMARY\s+KEY\s*\(([^)]*)\)/i
          columns_from_list($1).each { |c| mark_column!(table, c, primary_key: true) }
        when FOREIGN_KEY_RE
          m = item.match(FOREIGN_KEY_RE)
          from_cols = columns_from_list(m[:from])
          to_cols = columns_from_list(m[:to])
          ref_table = table_name_from(m[:table])
          on_delete = m[:tail][/ON\s+DELETE\s+(\w+(?:\s+\w+)?)/i, 1]
          on_update = m[:tail][/ON\s+UPDATE\s+(\w+(?:\s+\w+)?)/i, 1]

          from_cols.each_with_index do |from_col, i|
            pending_fks << {
              from_table: table_name, from_column: from_col,
              to_table: ref_table, to_column: to_cols[i] || to_cols.first,
              on_delete: on_delete, on_update: on_update
            }
          end
        when /\A#{OPTIONAL_CONSTRAINT_NAME_SRC}UNIQUE\s*\(([^)]*)\)/i
          cols = columns_from_list($1)
          if cols.size == 1
            mark_column!(table, cols.first, unique: true)
          else
            table[:indexes] << { name: "unique_#{table_name}_#{cols.join('_')}", unique: true, columns: cols }
          end
        when /\A(?<unique>UNIQUE\s+)?(?:KEY|INDEX)\s+(?<name>#{IDENTIFIER_SRC})\s*\((?<cols>[^)]*)\)/i
          m = item.match(/\A(?<unique>UNIQUE\s+)?(?:KEY|INDEX)\s+(?<name>#{IDENTIFIER_SRC})\s*\((?<cols>[^)]*)\)/i)
          table[:indexes] << { name: unquote(m[:name]), unique: !m[:unique].nil?, columns: columns_from_list(m[:cols]) }
        when /\A(?:CONSTRAINT\s+#{IDENTIFIER_SRC}\s+)?CHECK\s*\(/i
          table[:notes] << item
        else
          warnings << "Couldn't classify a constraint on #{table_name}: #{item.truncate(80)}" if item.present?
        end
      end

      def parse_column_definition(item, table, pending_fks, table_name)
        match = item.match(/\A(#{IDENTIFIER_SRC})\s+(.*)\z/m)
        return unless match

        col_name = unquote(match[1])
        rest = match[2]

        keyword_index = rest =~ /\b(NOT\s+NULL|NULL|PRIMARY\s+KEY|UNIQUE|DEFAULT|REFERENCES|CHECK|COLLATE|GENERATED)\b/i
        data_type = (keyword_index ? rest[0...keyword_index] : rest).strip

        default_value = nil
        if (m = rest.match(/\bDEFAULT\s+('(?:[^']|'')*'|[^\s,]+)/i))
          default_value = unquote_default(m[1])
        end

        if (m = rest.match(/\bREFERENCES\s+(#{IDENTIFIER_SRC}(?:\.#{IDENTIFIER_SRC})?)\s*\(([^)]*)\)/i))
          pending_fks << {
            from_table: table_name, from_column: col_name,
            to_table: table_name_from(m[1]), to_column: columns_from_list(m[2]).first,
            on_delete: nil, on_update: nil
          }
        end

        table[:columns] << {
          name: col_name,
          data_type: data_type.presence,
          nullable: !rest.match?(/\bNOT\s+NULL\b/i),
          primary_key: rest.match?(/\bPRIMARY\s+KEY\b/i),
          unique: rest.match?(/\bUNIQUE\b/i),
          default_value: default_value
        }
      end

      def mark_column!(table, col_name, **flags)
        col = table[:columns].find { |c| c[:name].casecmp?(col_name) }
        return unless col

        flags.each { |key, value| col[key] = value }
      end

      def columns_from_list(str)
        str.to_s.split(",").map { |c| unquote(c) }
      end

      def unquote(token)
        token.to_s.strip.gsub(/\A["`]|["`]\z/, "")
      end

      def unquote_default(token)
        if token.start_with?("'") && token.end_with?("'")
          token[1..-2].gsub("''", "'")
        else
          token
        end
      end

      def table_name_from(token)
        unquote(token.to_s.split(".").last)
      end
  end
end
