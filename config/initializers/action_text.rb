# ActionText's sanitizer strips table tags (table/thead/tbody/tr/th/td/...)
# by default, since Trix's own vocabulary never needed them. Tables are an
# ActionText attachment (see ContentTable), rendered as a real <table>
# both in Trix's own preview and the published page — this is the one
# piece standing between that and the tag actually surviving.
#
# Callouts (see Callout) needed no equivalent entry here: they're also an
# attachment, but render as a plain <div>, already allowed by default.
Rails.application.reloader.to_prepare do
  sanitizer_class = ActionText::ContentHelper.sanitizer.class

  ActionText::ContentHelper.allowed_tags =
    sanitizer_class.allowed_tags + [ ActionText::Attachment.tag_name, "figure", "figcaption" ] +
    %w[table thead tbody tfoot tr th td caption colgroup col]

  ActionText::ContentHelper.allowed_attributes =
    sanitizer_class.allowed_attributes + ActionText::Attachment::ATTRIBUTES +
    %w[colspan rowspan scope]
end
