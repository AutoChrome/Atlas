require "test_helper"

class ChartIndicesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "new renders the add-index form for a table that belongs to this chart" do
    get new_area_chart_chart_index_path(areas(:one), charts(:one), chart_table_id: chart_tables(:one).id)

    assert_response :success
    assert_select "form"
  end

  test "new rejects a chart_table_id belonging to a different chart" do
    other_chart_table = chart_tables(:other_chart_table) # lives on charts(:two), not charts(:one)

    get new_area_chart_chart_index_path(areas(:one), charts(:one), chart_table_id: other_chart_table.id)

    assert_response :not_found
  end
end
