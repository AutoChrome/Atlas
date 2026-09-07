require "test_helper"

class ContentTablesControllerTest < ActionDispatch::IntegrationTest
  test "create requires an editor role" do
    post content_tables_path
    assert_redirected_to new_session_path
  end

  test "create makes a blank table and returns its sgid and rendered preview" do
    sign_in_as(users(:one))

    assert_difference "ContentTable.count", 1 do
      post content_tables_path, as: :json
    end

    body = JSON.parse(response.body)
    table = ContentTable.last
    assert_equal table.attachable_sgid, body["sgid"]
    assert_match "rich-text-table", body["content"]
  end

  test "edit requires an editor role" do
    table = content_tables(:one)
    get edit_content_table_path(table)
    assert_redirected_to new_session_path
  end

  test "edit renders the genuinely-editable version, with contenteditable cells" do
    sign_in_as(users(:one))
    table = content_tables(:one)

    get edit_content_table_path(table), as: :json

    assert_response :success
    assert_match 'contenteditable="true"', response.body
    assert_match "content-table#addRow", response.body
  end

  test "update replaces a table's data from a JSON-encoded string" do
    sign_in_as(users(:one))
    table = content_tables(:one)

    patch content_table_path(table),
      params: { content_table: { data: [ [ "x", "y" ] ].to_json } }, as: :json

    assert_response :success
    assert_equal [ [ "x", "y" ] ], table.reload.data
  end

  # rich_text_table_controller.js uses this to push the edit straight into
  # the live Trix attachment (see its refreshAttachment) — without it, the
  # in-editor preview wouldn't change until the page was saved and reloaded.
  test "update returns the freshly-rendered preview so the live Trix attachment can be refreshed" do
    sign_in_as(users(:one))
    table = content_tables(:one)

    patch content_table_path(table),
      params: { content_table: { data: [ [ "x", "y" ] ].to_json } }, as: :json

    body = JSON.parse(response.body)
    assert_equal table.id, body["id"]
    assert_match "x", body["content"]
    assert_match "rich-text-table--#{table.id}", body["content"]
  end

  test "update rejects malformed JSON" do
    sign_in_as(users(:one))
    table = content_tables(:one)
    original = table.data

    patch content_table_path(table), params: { content_table: { data: "not json" } }, as: :json

    assert_response :unprocessable_entity
    assert_equal original, table.reload.data
  end

  test "update rejects data that isn't a valid grid" do
    sign_in_as(users(:one))
    table = content_tables(:one)

    patch content_table_path(table), params: { content_table: { data: [ [ "a" ], [ "b", "c" ] ].to_json } }, as: :json

    assert_response :unprocessable_entity
  end
end
