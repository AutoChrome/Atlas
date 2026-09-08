# A Note/Warning/Tip box embedded in a page's rich text — an ActionText
# attachment, the same architecture as ContentTable and for the same
# reason: registering these as native Trix block types (the way
# blockquote/heading/code work) looked simpler at first, but Trix's
# toolbar-driven *creation* path and its HTML *parsing* path turned out to
# read block-attribute config from different places — a custom block type
# registered at runtime works when you toggle it fresh, but is invisible
# to Trix's parser when it loads previously-saved content back into the
# editor (confirmed directly: the same test against the real built-in
# blockquote succeeds, against a runtime-registered tag it doesn't).
# Editing an existing page would silently stop recognizing its own
# callouts. An attachment sidesteps that entirely — Trix only ever tracks
# a reference (this record's signed global ID), the same mechanism
# already proven to round-trip correctly for tables.
class Callout < ApplicationRecord
  include ActionText::Attachable

  enum :variant, { note: 0, warning: 1, tip: 2 }, default: :note

  validates :variant, presence: true

  def self.blank(variant: :note)
    create!(variant: variant, body: "")
  end

  def to_attachable_partial_path
    "callouts/callout"
  end

  def to_trix_content_attachment_partial_path
    to_attachable_partial_path
  end

  # Used by ActionText::Attachment#to_plain_text (in turn used by
  # RichText#to_plain_text — see WebhookDeliveryJob's "raw text" payload
  # format) — without this override the default falls back to just the
  # attachment's caption, which is blank here, silently dropping every
  # callout from a plain-text rendering.
  def attachable_plain_text_representation(_caption = nil)
    "[#{variant.upcase}] #{body}"
  end
end
