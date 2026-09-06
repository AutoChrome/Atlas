require "test_helper"

class ChartIndexTest < ActiveSupport::TestCase
  test "requires a name and a column list" do
    index = chart_indices(:one)
    index.name = nil
    assert_not index.valid?

    index.name = "index_users_on_email"
    index.columns = nil
    assert_not index.valid?
  end

  test "column_names splits the comma-separated list" do
    index = ChartIndex.new(columns: "user_id, created_at")
    assert_equal %w[user_id created_at], index.column_names
  end
end
