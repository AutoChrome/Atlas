require "test_helper"

class CalloutTest < ActiveSupport::TestCase
  test ".blank defaults to a note with empty body" do
    callout = Callout.blank
    assert_equal "note", callout.variant
    assert_equal "", callout.body
  end

  test ".blank accepts an explicit variant" do
    assert_equal "warning", Callout.blank(variant: :warning).variant
    assert_equal "tip", Callout.blank(variant: :tip).variant
  end

  test "renders as a real ActionText attachable, the same read-only partial in both contexts" do
    callout = callouts(:one)

    assert_equal "callouts/callout", callout.to_attachable_partial_path
    assert_equal "callouts/callout", callout.to_trix_content_attachment_partial_path
    assert callout.attachable_sgid.present?
  end
end
