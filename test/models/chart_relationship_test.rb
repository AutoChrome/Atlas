require "test_helper"

class ChartRelationshipTest < ActiveSupport::TestCase
  test "resolves its tables through its columns rather than storing them separately" do
    rel = chart_relationships(:one)
    assert_equal chart_tables(:two), rel.from_chart_table
    assert_equal chart_tables(:one), rel.to_chart_table
  end

  test "allows a self-referencing relationship" do
    column = chart_columns(:users_id)
    rel = ChartRelationship.new(chart: charts(:one), from_chart_column: column, to_chart_column: column)
    assert rel.valid?
  end
end
