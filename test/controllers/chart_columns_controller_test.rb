require "test_helper"

class ChartColumnsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "new renders the add-column form for a table that belongs to this chart" do
    get new_area_chart_chart_column_path(areas(:one), charts(:one), chart_table_id: chart_tables(:one).id)

    assert_response :success
    assert_select "form"
  end

  test "new rejects a chart_table_id belonging to a different chart" do
    other_chart_table = chart_tables(:other_chart_table) # lives on charts(:two), not charts(:one)

    get new_area_chart_chart_column_path(areas(:one), charts(:one), chart_table_id: other_chart_table.id)

    assert_response :not_found
  end

  test "edit renders the edit form for a column that belongs to this chart" do
    get edit_area_chart_chart_column_path(areas(:one), charts(:one), chart_columns(:users_id))

    assert_response :success
    assert_select "form"
  end

  test "edit rejects a chart_column_id belonging to a different chart" do
    foreign_column = chart_columns(:other_chart_column) # lives on charts(:two)

    get edit_area_chart_chart_column_path(areas(:one), charts(:one), foreign_column)

    assert_response :not_found
  end

  test "create rejects a chart_table_id belonging to a different chart" do
    other_chart_table = chart_tables(:other_chart_table) # lives on charts(:two), not charts(:one)

    assert_no_difference "ChartColumn.count" do
      post area_chart_chart_columns_path(areas(:one), charts(:one)),
        params: { chart_column: { chart_table_id: other_chart_table.id, name: "sneaky" } }
    end

    assert_response :not_found
  end

  test "update rejects a chart_column_id belonging to a different chart" do
    foreign_column = chart_columns(:other_chart_column) # lives on charts(:two)

    patch area_chart_chart_column_path(areas(:one), charts(:one), foreign_column),
      params: { chart_column: { name: "hijacked" } }

    assert_response :not_found
    assert_equal "id", foreign_column.reload.name
  end

  test "create succeeds for a table that actually belongs to this chart" do
    table = chart_tables(:one)

    assert_difference "ChartColumn.count", 1 do
      post area_chart_chart_columns_path(areas(:one), charts(:one)),
        params: { chart_column: { chart_table_id: table.id, name: "new_column", nullable: "1" } }
    end

    assert_redirected_to area_chart_path(areas(:one), charts(:one))
  end
end
