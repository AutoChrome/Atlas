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

  # See RichTextPayload's "raw text" webhook format — without this, a
  # callout embedded in an announcement silently vanishes from plain-text
  # output entirely (the default falls back to just the attachment's
  # caption, which is always blank here).
  test "attachable_plain_text_representation prefixes the body with the variant" do
    callout = Callout.new(variant: :warning, body: "Be careful")

    assert_equal "[WARNING] Be careful", callout.attachable_plain_text_representation
  end
end
