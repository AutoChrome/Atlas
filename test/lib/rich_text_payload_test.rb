require "test_helper"

class RichTextPayloadTest < ActiveSupport::TestCase
  setup do
    @announcement = Announcement.new(
      title: "Test", starts_on: Date.current, ends_on: Date.current
    )
  end

  test "html renders plain formatted text, unwrapped from the app's own .trix-content styling div" do
    @announcement.content = "<div><strong>Some content</strong></div>"
    @announcement.save!(validate: false)

    html = RichTextPayload.new(@announcement.content).html

    assert_match "<strong>Some content</strong>", html
    refute_match "trix-content", html
  end

  # config.action_view.annotate_rendered_view_with_filenames is off in the
  # test environment (see config/environments/test.rb), so this has to
  # flip it on itself to actually exercise the stripping — otherwise this
  # test would pass even if the stripping code were deleted entirely.
  test "html strips view-annotation comments injected by rendering through ActionView" do
    original = ActionView::Base.annotate_rendered_view_with_filenames
    ActionView::Base.annotate_rendered_view_with_filenames = true

    @announcement.content = "<div><strong>Some content</strong></div>"
    @announcement.save!(validate: false)

    html = RichTextPayload.new(@announcement.content).html

    assert_match "<strong>Some content</strong>", html
    refute_match "BEGIN", html
    refute_match "<!--", html
  ensure
    ActionView::Base.annotate_rendered_view_with_filenames = original
  end

  test "html expands a ContentTable attachment to its real <table>, not just an empty attachment reference" do
    table = ContentTable.blank
    table.update!(data: [ [ "Name", "Role" ], [ "Ada", "Engineer" ] ])
    @announcement.content = ActionText::Attachment.from_attachable(table).to_html
    @announcement.save!(validate: false)

    html = RichTextPayload.new(@announcement.content).html

    assert_match "<table", html
    assert_match "Ada", html
    assert_match "Engineer", html
  end

  test "html expands a Callout attachment to its real markup" do
    callout = Callout.blank(variant: :warning)
    callout.update!(body: "Be careful")
    @announcement.content = ActionText::Attachment.from_attachable(callout).to_html
    @announcement.save!(validate: false)

    html = RichTextPayload.new(@announcement.content).html

    assert_match "rich-text-callout--warning", html
    assert_match "Be careful", html
  end

  test "plain_text strips formatting down to plain text" do
    @announcement.content = "<div><strong>Some</strong> <em>content</em></div>"
    @announcement.save!(validate: false)

    assert_equal "Some content", RichTextPayload.new(@announcement.content).plain_text
  end

  test "plain_text represents a ContentTable attachment instead of dropping it" do
    table = ContentTable.blank
    table.update!(data: [ [ "A", "B" ] ])
    @announcement.content = ActionText::Attachment.from_attachable(table).to_html
    @announcement.save!(validate: false)

    assert_equal "A | B", RichTextPayload.new(@announcement.content).plain_text
  end

  test "plain_text represents a Callout attachment instead of dropping it" do
    callout = Callout.blank(variant: :tip)
    callout.update!(body: "Nice to know")
    @announcement.content = ActionText::Attachment.from_attachable(callout).to_html
    @announcement.save!(validate: false)

    assert_equal "[TIP] Nice to know", RichTextPayload.new(@announcement.content).plain_text
  end
end
