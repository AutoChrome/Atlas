# Converts an array of Notion block objects (see NotionClient#retrieve_block_children,
# which pre-fetches nested children onto block["children"] — this never
# makes API calls of its own, purely a pure string transform for testability)
# into HTML for a Page's rich text content.
#
# Deliberately not exhaustive — Notion has far more block types than
# ActionText has an equivalent for. Handled: paragraph, heading_1/2/3,
# bulleted/numbered/to-do lists, quote, code, divider, image, callout
# (as a styled quote — Atlas's own Callout attachable isn't reachable from
# a plain string transform), toggle (as a bold line + its children, no
# real collapse — ActionText has nothing like <details> allow-listed), and
# a table. Anything else (child pages, embeds, synced blocks, columns,
# equations, files/video/audio, ...) is silently skipped rather than
# raising — a Notion page throwing an unexpected block type at this should
# degrade gracefully, not break the whole sync.
class NotionBlocksToHtml
  # to_do is grouped and rendered as a plain bulleted list, same as
  # bulleted_list_item — Notion's checkbox state doesn't have an Atlas
  # equivalent worth preserving (no interactive checkbox in ActionText),
  # so a synced to-do list just becomes an ordinary bullet list.
  LIST_TYPES = %w[bulleted_list_item numbered_list_item to_do].freeze

  # Notion authors commonly fake a heading by bolding an entire line
  # instead of using a real heading block (and that's exactly how the
  # toggle block below is rendered too) — CSS gives this class extra
  # margin-top so it still visually reads as a section break, the same way
  # a real h1/h2/h3 does, rather than running straight into the paragraph
  # above it. See .trix-content's :where(...) rule in components/_editor.scss.
  EMPHASIS_CLASS = "notion-emphasis"

  # Building a real ContentTable is a DB write, which this class
  # deliberately never does itself (see the class comment) — the caller
  # (NotionSyncJob) passes a builder that creates one and returns the
  # <action-text-attachment> tag referencing it. With no builder given
  # (e.g. direct/unit use of this class) a table falls back to a plain
  # <table>, preserving per-cell rich text formatting that a ContentTable's
  # plain-text-only cells can't hold anyway.
  def self.convert(blocks, table_builder: nil)
    new(table_builder).convert(blocks)
  end

  def initialize(table_builder = nil)
    @table_builder = table_builder
  end

  def convert(blocks)
    group_lists(blocks).map { |item| render_group_item(item) }.join
  end

  private
    # Consecutive list-type blocks of the SAME type need to share ONE
    # <ul>/<ol>, not get one each — this groups runs together first;
    # everything else passes through as a single-item group of its own.
    def group_lists(blocks)
      groups = []
      blocks.each do |block|
        type = block["type"]
        if LIST_TYPES.include?(type) && groups.last.is_a?(Array) && groups.last.first["type"] == type
          groups.last << block
        elsif LIST_TYPES.include?(type)
          groups << [ block ]
        else
          groups << block
        end
      end
      groups
    end

    def render_group_item(item)
      item.is_a?(Array) ? render_list(item) : render_block(item)
    end

    def render_list(items)
      tag = items.first["type"] == "numbered_list_item" ? "ol" : "ul"
      list_items = items.map { |block|
        "<li>#{render_rich_text(block.dig(block["type"], "rich_text"))}#{render_children(block)}</li>"
      }.join
      "<#{tag}>#{list_items}</#{tag}>"
    end

    def render_block(block)
      type = block["type"]
      data = block[type] || {}

      case type
      when "paragraph" then render_paragraph(data)
      when "heading_1" then "<h1>#{render_rich_text(data["rich_text"])}</h1>"
      when "heading_2" then "<h2>#{render_rich_text(data["rich_text"])}</h2>"
      when "heading_3" then "<h3>#{render_rich_text(data["rich_text"])}</h3>"
      when "quote" then "<blockquote>#{render_rich_text(data["rich_text"])}#{render_children(block)}</blockquote>"
      when "code" then render_code(data)
      when "divider" then "<hr>"
      when "image" then render_image(data)
      when "callout" then render_callout(data)
      when "toggle" then render_toggle(block, data)
      when "table" then render_table(block)
      else ""
      end
    end

    def render_paragraph(data)
      rich_text = data["rich_text"] || []
      css_class = fully_bold?(rich_text) ? " class=\"#{EMPHASIS_CLASS}\"" : ""
      "<p#{css_class}>#{render_rich_text(rich_text)}</p>"
    end

    def render_toggle(block, data)
      "<p class=\"#{EMPHASIS_CLASS}\"><strong>#{render_rich_text(data["rich_text"])}</strong></p>#{render_children(block)}"
    end

    def fully_bold?(rich_text_array)
      rich_text_array.present? && rich_text_array.all? { |rt|
        rt["plain_text"].blank? || rt.dig("annotations", "bold")
      }
    end

    def render_code(data)
      text = escape((data["rich_text"] || []).map { |t| t["plain_text"] }.join)
      "<pre><code>#{text}</code></pre>"
    end

    def render_image(data)
      url = data.dig("external", "url") || data.dig("file", "url")
      url.present? ? "<img src=\"#{escape(url)}\">" : ""
    end

    def render_callout(data)
      icon = data.dig("icon", "emoji")
      prefix = icon ? "#{icon} " : ""
      "<blockquote>#{prefix}#{render_rich_text(data["rich_text"])}</blockquote>"
    end

    def render_table(block)
      rows = (block["children"] || []).select { |b| b["type"] == "table_row" }
        .map { |row| row.dig("table_row", "cells") || [] }
      return "" if rows.empty?

      @table_builder ? @table_builder.call(rows.map { |cells| cells.map { |cell| plain_text(cell) } }) : render_plain_table(block, rows)
    end

    def render_plain_table(block, rows)
      has_header = block.dig("table", "has_column_header")
      row_html = rows.each_with_index.map { |cells, index|
        cell_tag = has_header && index.zero? ? "th" : "td"
        "<tr>" + cells.map { |cell| "<#{cell_tag}>#{render_rich_text(cell)}</#{cell_tag}>" }.join + "</tr>"
      }.join
      "<table>#{row_html}</table>"
    end

    def render_children(block)
      children = block["children"]
      children.present? ? convert(children) : ""
    end

    def render_rich_text(rich_text_array)
      (rich_text_array || []).map { |rt| render_rich_text_item(rt) }.join
    end

    def render_rich_text_item(rich_text)
      text = escape(rich_text["plain_text"] || "")
      annotations = rich_text["annotations"] || {}
      href = rich_text["href"]

      text = "<code>#{text}</code>" if annotations["code"]
      text = "<strong>#{text}</strong>" if annotations["bold"]
      text = "<em>#{text}</em>" if annotations["italic"]
      text = "<del>#{text}</del>" if annotations["strikethrough"]
      text = "<ins>#{text}</ins>" if annotations["underline"]
      text = "<a href=\"#{escape(href)}\">#{text}</a>" if href.present?
      text
    end

    def plain_text(rich_text_array)
      (rich_text_array || []).map { |rt| rt["plain_text"] }.join
    end

    def escape(string)
      ERB::Util.html_escape(string)
    end
end
