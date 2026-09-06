module IconHelper
  # Inline SVGs, read from real files (app/assets/images/icons/*.svg) and
  # inlined into the page rather than loaded via <img src="..."> — inlining
  # is what lets them pick up `currentColor` and resize with the
  # surrounding text/button, the same way an icon font would, without the
  # external-request failure mode an icon font has (see components/_icons.scss).
  ICONS_PATH = Rails.root.join("app/assets/images/icons")

  def icon(name, css_class: nil, size: 20)
    svg = ICONS_PATH.join("#{name}.svg").read
    svg.sub(
      "<svg ",
      %(<svg class="#{[ "icon", css_class ].compact.join(" ")}" width="#{size}" height="#{size}" aria-hidden="true" )
    ).html_safe
  end

  # A Font Awesome Free solid icon, e.g. fa_icon("rocket").
  def fa_icon(name, css_class: nil)
    tag.i class: [ "fa-solid", "fa-#{name}", "icon-fa", css_class ].compact.join(" "), aria: { hidden: "true" }
  end

  # A record's own chosen icon (see Iconable), falling back to a default
  # when it hasn't set one. The default is one of our own hand-drawn SVGs
  # by default (`fallback_style: :svg`, matching Area/Page's folder/page
  # glyphs) — pass `fallback_style: :fa` for a plain Font Awesome name
  # instead, for types (Chart, Tutorial) that don't have a bespoke SVG of
  # their own and just want a sensible FA icon as the un-set default.
  def record_icon(record, fallback:, css_class: nil, fallback_style: :svg)
    return fa_icon(record.icon, css_class: css_class) if record.icon.present?

    fallback_style == :fa ? fa_icon(fallback, css_class: css_class) : icon(fallback, css_class: css_class)
  end
end
