require "test_helper"

class SchemaRbParserTest < ActiveSupport::TestCase
  setup { @area = areas(:one) }

  test "imports tables, implicit primary keys, and add_foreign_key" do
    ruby = <<~RUBY
      ActiveRecord::Schema[7.1].define(version: 2024_01_01_000000) do
        create_table "users", force: :cascade do |t|
          t.string "email", null: false
          t.datetime "created_at", null: false
          t.index ["email"], name: "index_users_on_email", unique: true
        end

        create_table "posts", force: :cascade do |t|
          t.bigint "user_id", null: false
          t.string "title", null: false
          t.index ["user_id"], name: "index_posts_on_user_id"
        end

        add_foreign_key "posts", "users", on_delete: :cascade
      end
    RUBY

    result = SchemaRbParser.import(ruby: ruby, area: @area, title: "Schema Import")

    assert result.chart.present?, result.warnings.inspect
    assert_empty result.warnings

    users = result.chart.chart_tables.find_by!(name: "users")
    assert users.chart_columns.find_by(name: "id").primary_key?
    assert_equal "bigint", users.chart_columns.find_by(name: "id").data_type
    assert users.chart_columns.find_by(name: "email").unique?
    assert users.chart_columns.find_by(name: "email").indexed?

    rel = result.chart.chart_relationships.sole
    assert_equal "posts", rel.from_chart_column.chart_table.name
    assert_equal "user_id", rel.from_chart_column.name
    assert_equal "users", rel.to_chart_column.chart_table.name
    assert_equal "id", rel.to_chart_column.name
    assert_equal "cascade", rel.on_delete
  end

  test "honors id: :uuid and id: false table options" do
    ruby = <<~RUBY
      ActiveRecord::Schema[7.1].define(version: 1) do
        create_table "widgets", id: :uuid, force: :cascade do |t|
          t.string "name"
        end

        create_table "join_table", id: false, force: :cascade do |t|
          t.bigint "a_id"
          t.bigint "b_id"
        end
      end
    RUBY

    result = SchemaRbParser.import(ruby: ruby, area: @area, title: "PK Options Import")

    assert result.chart.present?, result.warnings.inspect
    widgets = result.chart.chart_tables.find_by!(name: "widgets")
    assert_equal "uuid", widgets.chart_columns.find_by(name: "id").data_type

    join_table = result.chart.chart_tables.find_by!(name: "join_table")
    assert_nil join_table.chart_columns.find_by(name: "id")
    assert_equal %w[a_id b_id], join_table.chart_columns.order(:position).map(&:name)
  end

  test "keeps a comma inside a quoted default intact instead of splitting on it" do
    ruby = <<~RUBY
      ActiveRecord::Schema[7.1].define(version: 1) do
        create_table "users", force: :cascade do |t|
          t.string "full_name", default: "Smith, John"
          t.integer "age"
        end
      end
    RUBY

    result = SchemaRbParser.import(ruby: ruby, area: @area, title: "Comma Import")

    assert result.chart.present?, result.warnings.inspect
    table = result.chart.chart_tables.sole
    assert_equal "Smith, John", table.chart_columns.find_by(name: "full_name").default_value
    assert_equal %w[id full_name age], table.chart_columns.order(:position).map(&:name)
  end

  test "never evaluates the uploaded content as Ruby code" do
    ruby = <<~RUBY
      ActiveRecord::Schema[7.1].define(version: 1) do
        create_table "users", force: :cascade do |t|
          t.string "name"
        end
      end
      Kernel.exit!(1) rescue nil
      $schema_rb_parser_test_marker = :evaluated
    RUBY

    SchemaRbParser.import(ruby: ruby, area: @area, title: "Safety Import")

    assert_nil defined?($schema_rb_parser_test_marker) && $schema_rb_parser_test_marker
  end

  test "reports a warning instead of raising when no tables are found" do
    result = SchemaRbParser.import(ruby: "# empty schema, nothing here", area: @area, title: "Empty")

    assert_nil result.chart
    assert_equal 1, result.warnings.size
  end
end
