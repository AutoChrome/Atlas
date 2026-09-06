require "test_helper"

class ChartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = areas(:one)
    @chart = charts(:one)
  end

  test "preview_import requires update permission" do
    sign_in_as(users(:one))

    file = fixture_file_upload("sample_schema.sql", "application/sql")
    post preview_import_area_chart_path(@area, @chart), params: { sql_file: file }

    assert_response :success
    assert_select "h1", "Review changes"
  end

  test "preview_import does not write anything to the database" do
    sign_in_as(users(:one))
    file = fixture_file_upload("sample_schema.sql", "application/sql")

    assert_no_difference [ "ChartTable.count", "ChartColumn.count" ] do
      post preview_import_area_chart_path(@area, @chart), params: { sql_file: file }
    end
  end

  test "apply_import persists the changes described by the payload" do
    sign_in_as(users(:one))

    parsed = SqlSchemaParser.parse(sql: "CREATE TABLE widgets (id uuid PRIMARY KEY);")
    payload = parsed.slice(:tables, :table_order, :pending_fks).to_json

    assert_difference "ChartTable.count", 1 do
      post apply_import_area_chart_path(@area, @chart), params: { import_payload: payload }
    end

    assert_redirected_to area_chart_path(@area, @chart)
  end

  test "an anonymous visitor cannot reach preview_import" do
    file = fixture_file_upload("sample_schema.sql", "application/sql")
    post preview_import_area_chart_path(@area, @chart), params: { sql_file: file }

    assert_redirected_to new_session_path
  end
end
