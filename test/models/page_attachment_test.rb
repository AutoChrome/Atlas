require "test_helper"

class PageAttachmentTest < ActiveSupport::TestCase
  setup do
    @page = pages(:one)
  end

  def attach(page_attachment)
    page_attachment.file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample_attachment.txt")),
      filename: "sample_attachment.txt",
      content_type: "text/plain"
    )
    page_attachment
  end

  test "valid with a page, a label, and an attached file" do
    page_attachment = attach(@page.page_attachments.build(label: "Contract"))

    assert page_attachment.valid?
  end

  test "invalid with a label longer than 255 characters" do
    page_attachment = @page.page_attachments.build(label: "a" * 256)

    assert_not page_attachment.valid?
    assert_includes page_attachment.errors[:label], "is too long (maximum is 255 characters)"
  end

  test "invalid with a download_filename longer than 255 characters" do
    page_attachment = @page.page_attachments.build(download_filename: "a" * 256)

    assert_not page_attachment.valid?
    assert_includes page_attachment.errors[:download_filename], "is too long (maximum is 255 characters)"
  end

  test "effective_filename falls back to the attached file's own filename when no override is set" do
    page_attachment = attach(@page.page_attachments.build)

    assert_equal "sample_attachment.txt", page_attachment.effective_filename
  end

  test "effective_filename prefers download_filename when one is set" do
    page_attachment = attach(@page.page_attachments.build(download_filename: "renamed.txt"))

    assert_equal "renamed.txt", page_attachment.effective_filename
  end

  test "destroying a page destroys its attachments" do
    page_attachment = attach(@page.page_attachments.build(label: "Contract"))
    page_attachment.save!

    @page.destroy

    assert_raises(ActiveRecord::RecordNotFound) { page_attachment.reload }
  end
end
