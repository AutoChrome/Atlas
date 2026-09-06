require "test_helper"

class SqlSchemaParserTest < ActiveSupport::TestCase
  setup { @area = areas(:one) }

  test "imports a Postgres-style ALTER TABLE ADD CONSTRAINT foreign key" do
    sql = <<~SQL
      CREATE TABLE public.users (id uuid PRIMARY KEY, email varchar(255) NOT NULL);
      CREATE TABLE public.posts (id uuid PRIMARY KEY, user_id uuid NOT NULL);
      ALTER TABLE ONLY public.posts ADD CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    SQL

    result = SqlSchemaParser.import(sql: sql, area: @area, title: "PG Import")

    assert result.chart.present?, result.warnings.inspect
    assert_empty result.warnings

    rel = result.chart.chart_relationships.sole
    assert_equal "posts", rel.from_chart_column.chart_table.name
    assert_equal "user_id", rel.from_chart_column.name
    assert_equal "users", rel.to_chart_column.chart_table.name
    assert_equal "id", rel.to_chart_column.name
    assert_equal "CASCADE", rel.on_delete
  end

  test "imports MySQL inline KEY constraints and discards trailing table options" do
    sql = <<~SQL
      CREATE TABLE `users` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `email` varchar(255) NOT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `index_users_on_email` (`email`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    SQL

    result = SqlSchemaParser.import(sql: sql, area: @area, title: "MySQL Import")

    assert result.chart.present?, result.warnings.inspect
    table = result.chart.chart_tables.sole
    assert_equal 2, table.chart_columns.count
    assert table.chart_columns.find_by(name: "id").primary_key?
    assert table.chart_columns.find_by(name: "email").indexed?
    assert table.chart_indices.sole.unique?
  end

  test "imports SQLite-style inline column REFERENCES" do
    sql = <<~SQL
      CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL UNIQUE);
      CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id));
    SQL

    result = SqlSchemaParser.import(sql: sql, area: @area, title: "SQLite Import")

    assert result.chart.present?, result.warnings.inspect
    rel = result.chart.chart_relationships.sole
    assert_equal "user_id", rel.from_chart_column.name
    assert_equal "id", rel.to_chart_column.name
  end

  test "keeps a comma inside a quoted DEFAULT string intact instead of splitting on it" do
    sql = <<~SQL
      CREATE TABLE public.users (
        id uuid PRIMARY KEY,
        full_name varchar(255) DEFAULT 'Smith, John',
        age integer
      );
    SQL

    result = SqlSchemaParser.import(sql: sql, area: @area, title: "Comma Import")

    assert result.chart.present?, result.warnings.inspect
    table = result.chart.chart_tables.sole
    assert_equal %w[id full_name age], table.chart_columns.order(:position).map(&:name)
    assert_equal "Smith, John", table.chart_columns.find_by(name: "full_name").default_value
  end

  test "reports a warning instead of raising when no tables are found" do
    result = SqlSchemaParser.import(sql: "-- nothing here", area: @area, title: "Empty")

    assert_nil result.chart
    assert_equal 1, result.warnings.size
  end
end
