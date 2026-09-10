# A single file attached to a Page, wrapped with metadata a bare
# ActiveStorage attachment has nowhere to hold — see the migration that
# created this table for why it exists instead of Page's old
# has_many_attached :attachments.
class PageAttachment < ApplicationRecord
  belongs_to :page
  has_one_attached :file, dependent: :purge_later

  validates :label, length: { maximum: 255 }
  validates :download_filename, length: { maximum: 255 }

  # What actually shows as the download's filename — the override if one's
  # set, otherwise whatever the file was originally uploaded as. Used via
  # rails_blob_path's own `filename:` option (see pages/show.html.erb),
  # which only changes what the browser names the saved file — it never
  # renames the underlying blob itself.
  def effective_filename
    download_filename.presence || file.filename.to_s
  end
end
