require "test_helper"

class ChartColumnTest < ActiveSupport::TestCase
  test "column names are unique within a table, case-insensitively" do
    dup = chart_columns(:users_id).chart_table.chart_columns.new(name: chart_columns(:users_id).name.upcase)
    assert_not dup.valid?
  end

  test "foreign_key? is true only for the column that actually references another" do
    assert chart_columns(:posts_user_id).foreign_key?
    assert_not chart_columns(:users_id).foreign_key?
  end

  test "indexed? is derived from the table's indexes, not a stored flag" do
    column = chart_columns(:users_id)
    assert_not column.indexed?

    column.chart_table.chart_indices.create!(name: "idx", unique: false, columns: "id, created_at")

    assert column.reload.indexed?
  end
end
