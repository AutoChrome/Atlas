require "test_helper"

class ChartTableTest < ActiveSupport::TestCase
  test "table names are unique within a chart, case-insensitively" do
    dup = chart_tables(:one).chart.chart_tables.new(name: chart_tables(:one).name.upcase)
    assert_not dup.valid?
  end

  test "indexed_column_names reflects every index on the table, single or composite" do
    table = chart_tables(:one)
    table.chart_indices.create!(name: "idx_users_composite", unique: false, columns: "email, created_at")

    assert_equal Set["email", "created_at"], table.indexed_column_names
  end

  test "destroying a table cascades to its columns and any relationship touching them" do
    rel = chart_relationships(:one)
    from_table = rel.from_chart_column.chart_table

    from_table.destroy

    assert_not ChartRelationship.exists?(rel.id)
  end
end
