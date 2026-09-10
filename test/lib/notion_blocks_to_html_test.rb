require "test_helper"

class NotionBlocksToHtmlTest < ActiveSupport::TestCase
  def rich_text(content, annotations: {}, href: nil)
    {
      "type" => "text",
      "plain_text" => content,
      "href" => href,
      "annotations" => {
        "bold" => false, "italic" => false, "strikethrough" => false,
        "underline" => false, "code" => false
      }.merge(annotations)
    }
  end

  def block(type, data = {}, has_children: false, children: nil)
    b = { "type" => type, type => data, "has_children" => has_children }
    b["children"] = children if children
    b
  end

  test "converts a paragraph" do
    html = NotionBlocksToHtml.convert([ block("paragraph", { "rich_text" => [ rich_text("Hello") ] }) ])

    assert_equal "<p>Hello</p>", html
  end

  test "converts headings 1 through 3" do
    blocks = [
      block("heading_1", { "rich_text" => [ rich_text("H1") ] }),
      block("heading_2", { "rich_text" => [ rich_text("H2") ] }),
      block("heading_3", { "rich_text" => [ rich_text("H3") ] })
    ]

    assert_equal "<h1>H1</h1><h2>H2</h2><h3>H3</h3>", NotionBlocksToHtml.convert(blocks)
  end

  test "applies bold, italic, strikethrough, underline, and code annotations, nested correctly" do
    # A fully-bold paragraph gets notion-emphasis (see the dedicated tests
    # below) — that's incidental to this test, which is really about
    # annotation nesting order, so these two use a trailing plain run to
    # stay out of that path.
    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("bold", annotations: { "bold" => true }), rich_text(".") ] })
    ])
    assert_equal "<p><strong>bold</strong>.</p>", html

    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("both", annotations: { "bold" => true, "italic" => true }), rich_text(".") ] })
    ])
    assert_equal "<p><em><strong>both</strong></em>.</p>", html

    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("struck", annotations: { "strikethrough" => true }) ] })
    ])
    assert_equal "<p><del>struck</del></p>", html

    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("under", annotations: { "underline" => true }) ] })
    ])
    assert_equal "<p><ins>under</ins></p>", html

    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("code", annotations: { "code" => true }) ] })
    ])
    assert_equal "<p><code>code</code></p>", html
  end

  test "wraps a rich text run with an href in a link" do
    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("Atlas", href: "https://example.com") ] })
    ])

    assert_equal '<p><a href="https://example.com">Atlas</a></p>', html
  end

  test "escapes HTML-significant characters in plain text" do
    html = NotionBlocksToHtml.convert([ block("paragraph", { "rich_text" => [ rich_text("<script>alert(1)</script>") ] }) ])

    assert_equal "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>", html
  end

  test "groups consecutive bulleted_list_item blocks into one ul, not one per item" do
    blocks = [
      block("bulleted_list_item", { "rich_text" => [ rich_text("One") ] }),
      block("bulleted_list_item", { "rich_text" => [ rich_text("Two") ] })
    ]

    assert_equal "<ul><li>One</li><li>Two</li></ul>", NotionBlocksToHtml.convert(blocks)
  end

  test "groups consecutive numbered_list_item blocks into one ol" do
    blocks = [
      block("numbered_list_item", { "rich_text" => [ rich_text("One") ] }),
      block("numbered_list_item", { "rich_text" => [ rich_text("Two") ] })
    ]

    assert_equal "<ol><li>One</li><li>Two</li></ol>", NotionBlocksToHtml.convert(blocks)
  end

  test "starts a new list when the list type changes, rather than merging bullets and numbers" do
    blocks = [
      block("bulleted_list_item", { "rich_text" => [ rich_text("Bullet") ] }),
      block("numbered_list_item", { "rich_text" => [ rich_text("Number") ] })
    ]

    assert_equal "<ul><li>Bullet</li></ul><ol><li>Number</li></ol>", NotionBlocksToHtml.convert(blocks)
  end

  test "a non-list block between two lists of the same type does not merge them" do
    blocks = [
      block("bulleted_list_item", { "rich_text" => [ rich_text("First") ] }),
      block("paragraph", { "rich_text" => [ rich_text("Between") ] }),
      block("bulleted_list_item", { "rich_text" => [ rich_text("Second") ] })
    ]

    assert_equal "<ul><li>First</li></ul><p>Between</p><ul><li>Second</li></ul>", NotionBlocksToHtml.convert(blocks)
  end

  test "converts a quote, including its nested children" do
    quote = block("quote", { "rich_text" => [ rich_text("Quoted") ] }, has_children: true,
      children: [ block("paragraph", { "rich_text" => [ rich_text("Nested") ] }) ])

    assert_equal "<blockquote>Quoted<p>Nested</p></blockquote>", NotionBlocksToHtml.convert([ quote ])
  end

  test "converts a code block using plain_text only, ignoring rich text formatting" do
    html = NotionBlocksToHtml.convert([
      block("code", { "rich_text" => [ rich_text("def foo", annotations: { "bold" => true }) ], "language" => "ruby" })
    ])

    assert_equal "<pre><code>def foo</code></pre>", html
  end

  test "converts a divider to hr" do
    assert_equal "<hr>", NotionBlocksToHtml.convert([ block("divider", {}) ])
  end

  test "converts to_do blocks into a plain bulleted list, regardless of checked state" do
    checked = block("to_do", { "rich_text" => [ rich_text("Done") ], "checked" => true })
    unchecked = block("to_do", { "rich_text" => [ rich_text("Not done") ], "checked" => false })

    assert_equal "<ul><li>Done</li></ul>", NotionBlocksToHtml.convert([ checked ])
    assert_equal "<ul><li>Not done</li></ul>", NotionBlocksToHtml.convert([ unchecked ])
  end

  test "groups consecutive to_do blocks into one ul" do
    blocks = [
      block("to_do", { "rich_text" => [ rich_text("One") ], "checked" => false }),
      block("to_do", { "rich_text" => [ rich_text("Two") ], "checked" => true })
    ]

    assert_equal "<ul><li>One</li><li>Two</li></ul>", NotionBlocksToHtml.convert(blocks)
  end

  test "converts an image block, preferring external url then file url" do
    external = block("image", { "external" => { "url" => "https://example.com/a.png" } })
    assert_equal '<img src="https://example.com/a.png">', NotionBlocksToHtml.convert([ external ])

    file = block("image", { "file" => { "url" => "https://notion-hosted.example.com/b.png" } })
    assert_equal '<img src="https://notion-hosted.example.com/b.png">', NotionBlocksToHtml.convert([ file ])
  end

  test "converts a callout with its emoji icon prefixed" do
    callout = block("callout", { "rich_text" => [ rich_text("Careful") ], "icon" => { "type" => "emoji", "emoji" => "⚠️" } })

    assert_equal "<blockquote>⚠️ Careful</blockquote>", NotionBlocksToHtml.convert([ callout ])
  end

  test "converts a toggle as a bold line marked notion-emphasis, followed by its children, with no collapse" do
    toggle = block("toggle", { "rich_text" => [ rich_text("Summary") ] }, has_children: true,
      children: [ block("paragraph", { "rich_text" => [ rich_text("Detail") ] }) ])

    assert_equal '<p class="notion-emphasis"><strong>Summary</strong></p><p>Detail</p>', NotionBlocksToHtml.convert([ toggle ])
  end

  test "marks a fully-bold paragraph as notion-emphasis, so it gets heading-like spacing above it" do
    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [ rich_text("Section title", annotations: { "bold" => true }) ] })
    ])

    assert_equal '<p class="notion-emphasis"><strong>Section title</strong></p>', html
  end

  test "does not mark a paragraph notion-emphasis when only part of it is bold" do
    html = NotionBlocksToHtml.convert([
      block("paragraph", { "rich_text" => [
        rich_text("Bold", annotations: { "bold" => true }),
        rich_text(" and plain")
      ] })
    ])

    assert_equal "<p><strong>Bold</strong> and plain</p>", html
  end

  test "converts a table, marking the first row as headers when has_column_header is true" do
    table = block("table", { "has_column_header" => true }, has_children: true, children: [
      { "type" => "table_row", "table_row" => { "cells" => [ [ rich_text("Name") ], [ rich_text("Role") ] ] } },
      { "type" => "table_row", "table_row" => { "cells" => [ [ rich_text("Ada") ], [ rich_text("Engineer") ] ] } }
    ])

    assert_equal "<table><tr><th>Name</th><th>Role</th></tr><tr><td>Ada</td><td>Engineer</td></tr></table>",
      NotionBlocksToHtml.convert([ table ])
  end

  test "passes a table's rows as plain-text cells to a given table_builder, instead of rendering a plain <table>" do
    table = block("table", { "has_column_header" => true }, has_children: true, children: [
      { "type" => "table_row", "table_row" => { "cells" => [ [ rich_text("Name") ], [ rich_text("Role") ] ] } },
      { "type" => "table_row", "table_row" => {
        "cells" => [ [ rich_text("Ada") ], [ rich_text("Engineer", annotations: { "bold" => true }) ] ] } }
    ])

    captured = nil
    builder = ->(rows) { captured = rows; "<CUSTOM-TABLE>" }

    html = NotionBlocksToHtml.convert([ table ], table_builder: builder)

    assert_equal "<CUSTOM-TABLE>", html
    assert_equal [ [ "Name", "Role" ], [ "Ada", "Engineer" ] ], captured
  end

  test "silently skips an unsupported block type instead of raising" do
    assert_equal "", NotionBlocksToHtml.convert([ block("child_page", { "title" => "Nested page" }) ])
  end

  test "converts a realistic mixed page" do
    blocks = [
      block("heading_1", { "rich_text" => [ rich_text("Deploying to production") ] }),
      block("paragraph", { "rich_text" => [ rich_text("Follow these steps:") ] }),
      block("numbered_list_item", { "rich_text" => [ rich_text("Run tests") ] }),
      block("numbered_list_item", { "rich_text" => [ rich_text("Merge to main") ] }),
      block("divider", {}),
      block("callout", { "rich_text" => [ rich_text("Never skip step 1") ], "icon" => { "emoji" => "⚠️" } })
    ]

    expected = "<h1>Deploying to production</h1>" \
      "<p>Follow these steps:</p>" \
      "<ol><li>Run tests</li><li>Merge to main</li></ol>" \
      "<hr>" \
      "<blockquote>⚠️ Never skip step 1</blockquote>"

    assert_equal expected, NotionBlocksToHtml.convert(blocks)
  end
end
