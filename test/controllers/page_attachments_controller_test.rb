require "test_helper"

class PageAttachmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = areas(:one)
    @page = pages(:one)
    @page_attachment = @page.page_attachments.create!(download_filename: "renamed.pdf")
    @page_attachment.file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample_attachment.txt")),
      filename: "original.txt", content_type: "text/plain"
    )
  end

  test "download redirects to the blob's own service URL, not the cosmetic-filename-only redirect route" do
    sign_in_as(users(:one))

    get download_area_page_page_attachment_path(@area, @page, @page_attachment)

    assert_response :redirect
    # /rails/active_storage/blobs/redirect/... is Rails' own rails_blob_path
    # route — it always serves under the blob's ORIGINAL filename no matter
    # what filename: option you pass it (see the comment on
    # PageAttachmentsController#download). Going straight to the service
    # (disk here, in test) is what actually lets the custom filename apply.
    assert_no_match %r{/rails/active_storage/blobs/redirect/}, response.location
  end

  test "download honors the custom download_filename in the redirected URL" do
    sign_in_as(users(:one))

    get download_area_page_page_attachment_path(@area, @page, @page_attachment)

    assert_match "renamed.pdf", response.location
  end

  test "an anonymous visitor can download an attachment on a public page" do
    @page.update!(public: true)

    get download_area_page_page_attachment_path(@area, @page, @page_attachment)

    assert_response :redirect
  end

  test "an anonymous visitor cannot download an attachment on a private page" do
    @page.update!(public: false)

    get download_area_page_page_attachment_path(@area, @page, @page_attachment)

    assert_redirected_to new_session_path
  end
end
