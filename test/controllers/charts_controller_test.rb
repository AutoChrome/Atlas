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

  test "elsewhere returns a blank result without touching search for a blank query" do
    sign_in_as(users(:one))

    get elsewhere_area_chart_path(@area, @chart), params: { q: "" }, as: :json

    assert_response :success
    assert_equal [], JSON.parse(response.body)["results"]
  end

  test "elsewhere reports which of another chart's own tables/columns matched, excluding this chart itself" do
    sign_in_as(users(:one))
    other_chart = charts(:two) # has chart_tables(:other_chart_table), named "widgets"

    with_search_stub(Chart, ->(*) { [ other_chart ] }) do
      get elsewhere_area_chart_path(@area, @chart), params: { q: "widgets" }, as: :json
    end

    assert_response :success
    results = JSON.parse(response.body)["results"]
    assert_equal 1, results.size
    assert_equal other_chart.title, results.first["chart_title"]
    assert_equal other_chart.area.name, results.first["area_name"]
    # A rendered preview of the matched table (see chart_tables/_preview),
    # not just its name — includes the table name and, since PK: true is
    # set on chart_columns(:other_chart_column), its PK badge.
    assert_match "widgets", results.first["tables_html"]
    assert_match "PK", results.first["tables_html"]
    # The search term rides along in the URL (see chart_search_controller.js's
    # connect) so following this link lands on the other chart with the same
    # search already active, showing its own hint pointing back — otherwise
    # a genuinely two-way relationship only ever shows up from one side.
    assert_equal "q=widgets", URI.parse(results.first["url"]).query
  end

  test "elsewhere reports each matched column's name and whether it's a primary key, for the searching chart to annotate its own matching columns" do
    sign_in_as(users(:one))
    other_chart = charts(:two) # chart_tables(:other_chart_table) has a PK column named "id"

    with_search_stub(Chart, ->(*) { [ other_chart ] }) do
      get elsewhere_area_chart_path(@area, @chart), params: { q: "id" }, as: :json
    end

    assert_response :success
    results = JSON.parse(response.body)["results"]
    assert_equal [ { "name" => "id", "primary_key" => true } ], results.first["matched_columns"]
  end

  test "elsewhere returns no matched_columns when only a table name matched, not any column" do
    sign_in_as(users(:one))
    other_chart = charts(:two)

    with_search_stub(Chart, ->(*) { [ other_chart ] }) do
      get elsewhere_area_chart_path(@area, @chart), params: { q: "widgets" }, as: :json
    end

    assert_response :success
    assert_equal [], JSON.parse(response.body)["results"].first["matched_columns"]
  end

  test "elsewhere excludes a returned chart whose tables don't actually match by name (a title/description-only hit)" do
    sign_in_as(users(:one))
    other_chart = charts(:two)

    with_search_stub(Chart, ->(*) { [ other_chart ] }) do
      get elsewhere_area_chart_path(@area, @chart), params: { q: "no_such_table_or_column" }, as: :json
    end

    assert_response :success
    assert_equal [], JSON.parse(response.body)["results"]
  end

  test "an anonymous visitor can reach elsewhere for a publicly visible chart" do
    @area.update!(public: true)

    get elsewhere_area_chart_path(@area, @chart), params: { q: "anything" }, as: :json

    assert_response :success
  end
end
