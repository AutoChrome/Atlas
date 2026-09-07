require "test_helper"

class CalloutsControllerTest < ActionDispatch::IntegrationTest
  test "create requires an editor role" do
    post callouts_path
    assert_redirected_to new_session_path
  end

  test "create makes a blank note callout by default and returns its sgid and rendered preview" do
    sign_in_as(users(:one))

    assert_difference "Callout.count", 1 do
      post callouts_path, as: :json
    end

    callout = Callout.last
    assert_equal "note", callout.variant

    body = JSON.parse(response.body)
    assert_equal callout.attachable_sgid, body["sgid"]
    assert_match "rich-text-callout--note", body["content"]
  end

  test "create honors an explicit variant" do
    sign_in_as(users(:one))

    post callouts_path, params: { variant: "warning" }, as: :json

    assert_equal "warning", Callout.last.variant
  end

  test "create falls back to note for an unrecognized variant rather than raising" do
    sign_in_as(users(:one))

    post callouts_path, params: { variant: "not_a_real_variant" }, as: :json

    assert_response :success
    assert_equal "note", Callout.last.variant
  end

  test "edit requires an editor role" do
    callout = callouts(:one)
    get edit_callout_path(callout)
    assert_redirected_to new_session_path
  end

  test "edit renders the genuinely-editable version, with a contenteditable body and variant picker" do
    sign_in_as(users(:one))
    callout = callouts(:one)

    get edit_callout_path(callout), as: :json

    assert_response :success
    assert_match 'contenteditable="true"', response.body
    assert_match "callout#setVariant", response.body
  end

  test "update replaces the body and variant" do
    sign_in_as(users(:one))
    callout = callouts(:one)

    patch callout_path(callout), params: { body: "Updated text", variant: "tip" }, as: :json

    assert_response :success
    callout.reload
    assert_equal "Updated text", callout.body
    assert_equal "tip", callout.variant
  end

  test "update rejects an invalid variant instead of raising" do
    sign_in_as(users(:one))
    callout = callouts(:one)
    original_variant = callout.variant

    patch callout_path(callout), params: { variant: "not_a_real_variant" }, as: :json

    assert_response :unprocessable_entity
    assert_equal original_variant, callout.reload.variant
  end
end
