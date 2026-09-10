# Wraps a single attached file (has_one_attached :file, see PageAttachment)
# with metadata the file itself has no room for — a human-readable label
# ("Q3 budget spreadsheet") and an optional override for what filename a
# download shows, independent of whatever the file was originally named on
# the uploader's own computer. Replaces Page's old has_many_attached
# :attachments, which had nowhere to hang either of those — confirmed via
# a direct data check before this migration that nothing was actually
# using it yet, so there's no existing data to carry over.
class CreatePageAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :page_attachments do |t|
      t.references :page, null: false, foreign_key: true
      t.string :label
      t.string :download_filename

      t.timestamps
    end
  end
end
