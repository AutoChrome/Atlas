# Renders an ActionText::RichText for outbound consumption (see
# WebhookDeliveryJob) in whichever format a Webhook is configured to send
# (see Webhook#content_format) — never used for the app's own page
# rendering, which goes through ActionText's normal helpers directly.
class RichTextPayload
  def initialize(rich_text)
    @rich_text = rich_text
  end

  # Full HTML with every attachment (ContentTable, Callout, an image, ...)
  # expanded to its real rendered markup, exactly as authored — NOT
  # `rich_text.body.fragment.source.to_html` (what WebhookDeliveryJob used
  # before this existed), which only stores an
  # `<action-text-attachment sgid="...">` reference with no inner content,
  # silently dropping every table and callout from the payload entirely.
  #
  # Rendering through `.to_s` (ActionView) is what actually expands
  # attachments, but in development it also injects view-annotation HTML
  # comments (config.action_view.annotate_rendered_view_with_filenames)
  # into every partial it renders, including nested attachment partials —
  # stripped here via Nokogiri rather than avoided at render time, so this
  # behaves identically regardless of that dev-only setting. The app's own
  # layouts/action_text/contents/_content.html.erb wraps everything in a
  # `.trix-content` div purely for the app's own page styling — unwrapped
  # here since a webhook receiver has no use for that class.
  def html
    fragment.inner_html.strip
  end

  # Attachments need their own plain-text representation (see
  # ContentTable/Callout's attachable_plain_text_representation) or
  # they'd silently vanish here too — the built-in fallback is just the
  # attachment's caption, which is blank for both.
  def plain_text
    @rich_text.to_plain_text
  end

  private
    def fragment
      @fragment ||= begin
        parsed = Nokogiri::HTML::DocumentFragment.parse(@rich_text.to_s)
        parsed.xpath(".//comment()").remove
        wrapper = parsed.at_css(".trix-content")
        wrapper ? Nokogiri::HTML::DocumentFragment.parse(wrapper.inner_html) : parsed
      end
    end
end
