require "test_helper"

class ChartImportSyncTest < ActiveSupport::TestCase
  setup do
    @chart = charts(:one)
    @users = chart_tables(:one) # belongs to charts(:one), name "users"
  end

  test "matches an existing table case-insensitively, not as a new table" do
    @users.update!(name: "Users")
    parsed = SqlSchemaParser.parse(sql: "CREATE TABLE users (id uuid PRIMARY KEY);")

    diff = ChartImportSync.diff(chart: @chart, **parsed.slice(:tables, :table_order, :pending_fks))

    table_plan = diff.table_plans.sole
    assert_not table_plan.new?
    assert_equal @users, table_plan.table
  end

  test "treats a genuinely different name as a new table, leaving the existing one alone" do
    parsed = SqlSchemaParser.parse(sql: "CREATE TABLE user (id uuid PRIMARY KEY);")

    diff = ChartImportSync.diff(chart: @chart, **parsed.slice(:tables, :table_order, :pending_fks))

    assert diff.table_plans.sole.new?
    assert_includes diff.unmatched_tables, @users
  end

  test "detects changed column attributes without altering unmentioned columns" do
    # chart_columns(:users_id) is fixture-seeded with unique: false — a
    # column of the same (case-insensitive) name with `unique` flipped on
    # should surface as a change, not a brand-new column.
    parsed = SqlSchemaParser.parse(sql: "CREATE TABLE users (id uuid UNIQUE PRIMARY KEY);")

    diff = ChartImportSync.diff(chart: @chart, **parsed.slice(:tables, :table_order, :pending_fks))
    id_plan = diff.table_plans.sole.column_plans.find { |cp| cp.name == "id" }

    assert_not id_plan.new?
    assert id_plan.changes.key?(:unique)
  end

  test "apply! adds new tables/columns and updates changed columns, without touching unrelated data" do
    other_table_id = chart_tables(:two).id

    parsed = SqlSchemaParser.parse(sql: <<~SQL)
      CREATE TABLE users (id uuid PRIMARY KEY, email varchar(255) NOT NULL UNIQUE, name varchar(100));
      CREATE TABLE comments (id uuid PRIMARY KEY, user_id uuid NOT NULL);
      ALTER TABLE ONLY comments ADD CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    SQL

    assert_difference "ChartTable.count", 1 do
      ChartImportSync.apply!(chart: @chart, **parsed.slice(:tables, :table_order, :pending_fks))
    end
    @chart.reload

    users = @chart.chart_tables.find_by(name: "users")
    assert users.chart_columns.find_by(name: "email").unique?
    assert users.chart_columns.find_by(name: "name").present?

    comments = @chart.chart_tables.find_by(name: "comments")
    assert comments.present?
    assert comments.chart_columns.find_by(name: "user_id").foreign_key?

    # The other fixture chart's table is untouched.
    assert ChartTable.exists?(other_table_id)
  end

  test "apply! is idempotent — running it twice does not duplicate columns or relationships" do
    parsed = SqlSchemaParser.parse(sql: <<~SQL)
      CREATE TABLE users (id uuid PRIMARY KEY, email varchar(255) NOT NULL UNIQUE);
      CREATE TABLE comments (id uuid PRIMARY KEY, user_id uuid NOT NULL);
      ALTER TABLE ONLY comments ADD CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    SQL

    relationship_count_before = @chart.chart_relationships.count

    2.times { ChartImportSync.apply!(chart: @chart, **parsed.slice(:tables, :table_order, :pending_fks)) }
    @chart.reload

    comments = @chart.chart_tables.find_by(name: "comments")
    assert_equal 2, comments.chart_columns.count
    # +1 for the new comments->users relationship — the fixture's existing
    # posts->users relationship is untouched, not duplicated.
    assert_equal relationship_count_before + 1, @chart.chart_relationships.count
  end
end
