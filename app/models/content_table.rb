# A table embedded in a Page's rich text content — see
# rich_text_table_controller.js for why this exists at all: Trix has no
# native concept of tables, and (unlike a plain <a> link) a <table>'s
# structure doesn't survive being run through Trix's own HTML parser via
# insertHTML, which only understands its own limited block/inline
# vocabulary and mangles anything outside it. An ActionText attachable
# sidesteps that: Trix only ever tracks a reference (this record's signed
# global ID) to it, never tries to reparse its content.
#
# That reference is tracked via an attribute Trix manages itself, which
# survives — but Trix *also* runs whatever HTML that attachment renders
# through its own client-side sanitizer, which strips virtually every
# attribute down to `class` and unwraps any element it doesn't recognize
# entirely (confirmed directly: contenteditable, data-controller, and even
# a bare <turbo-frame> placeholder all got stripped or removed outright).
# So there's no way to make cells directly, inline editable *within* Trix's
# own rendered preview — both the in-editor preview and the published page
# render the exact same read-only content_tables/content_table partial.
# Editing instead happens in a dialog (content_table_controller.js), whose
# content is delivered as an ordinary page fragment rather than embedded in
# an attachment's content string, so it's never subject to that
# sanitization at all.
class ContentTable < ApplicationRecord
  include ActionText::Attachable

  DEFAULT_ROWS = 3
  DEFAULT_COLUMNS = 3

  validate :data_is_a_grid_of_text

  def self.blank(rows: DEFAULT_ROWS, columns: DEFAULT_COLUMNS)
    create!(data: Array.new(rows) { Array.new(columns, "") })
  end

  def column_count
    data.first&.size.to_i
  end

  def to_attachable_partial_path
    "content_tables/content_table"
  end

  def to_trix_content_attachment_partial_path
    to_attachable_partial_path
  end

  private
    def data_is_a_grid_of_text
      unless data.is_a?(Array) && data.all? { |row| row.is_a?(Array) && row.all?(String) }
        errors.add(:data, "must be an array of rows of text cells")
        return
      end

      errors.add(:data, "rows must all have the same number of columns") if data.map(&:size).uniq.size > 1
    end
end
