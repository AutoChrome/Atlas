class PageAttachmentsController < ApplicationController
  # Required by Blob#url below (see the comment on #download) — Rails only
  # sets ActiveStorage::Current.url_options automatically for its own
  # ActiveStorage::BaseController subclasses, not for ours.
  include ActiveStorage::SetCurrent

  allow_unauthenticated_access only: %i[download]

  before_action :set_area
  before_action :set_page
  before_action :set_page_attachment

  # Rails' own rails_blob_path only ever serves a blob under its original
  # filename — the filename: option it accepts just decorates the URL, it
  # isn't forwarded to the redirect/proxy controllers that actually set
  # Content-Disposition (confirmed directly against the activestorage gem
  # source: ActiveStorage::Blobs::RedirectController#show calls
  # @blob.url(disposition: params[:disposition]) with no filename at all).
  # Calling Blob#url ourselves, here, is the only way to actually honor a
  # per-attachment download_filename override.
  def download
    authorize @page, :show?

    redirect_to @page_attachment.file.blob.url(
      disposition: "attachment",
      filename: ActiveStorage::Filename.new(@page_attachment.effective_filename)
    ), allow_other_host: true
  end

  private
    def set_area
      @area = Area.friendly.find(params[:area_slug])
    end

    def set_page
      @page = @area.pages.friendly.find(params[:page_slug])
    end

    def set_page_attachment
      @page_attachment = @page.page_attachments.find(params[:id])
    end
end
