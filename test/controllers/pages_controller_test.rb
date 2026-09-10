require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = areas(:one)
    @other_area = areas(:two)
    @page = pages(:one)
    sign_in_as(users(:one))
  end

  test "updating area_id moves the page to the new area" do
    patch area_page_path(@area, @page), params: { page: { area_id: @other_area.id } }

    assert_equal @other_area, @page.reload.area
  end

  test "redirects to the page's new area after a move, not the area the request came in on" do
    patch area_page_path(@area, @page), params: { page: { area_id: @other_area.id } }

    assert_redirected_to area_page_path(@other_area, @page.reload)
  end

  test "not specifying area_id leaves the page in its current area" do
    patch area_page_path(@area, @page), params: { page: { title: "Renamed" } }

    assert_equal @area, @page.reload.area
    assert_redirected_to area_page_path(@area, @page)
  end

  # Confirmed directly (not assumed): FriendlyId's :scoped module detects
  # the scope column (area_id) changing and regenerates the slug, rather
  # than validating the OLD slug against the new scope and failing. A
  # genuine collision gets a randomized-suffix slug, not a validation
  # error — this locks in that a move never silently corrupts or overwrites
  # another page's slug.
  test "moving into an area with a genuine title collision still succeeds, with a distinct (if uglier) slug" do
    @page.update!(title: "Shared Title")
    colliding = @other_area.pages.create!(title: "Shared Title")

    patch area_page_path(@area, @page), params: { page: { area_id: @other_area.id } }

    assert_response :redirect
    @page.reload
    assert_equal @other_area, @page.area
    assert_not_equal colliding.slug, @page.slug
  end

  test "creating a page with an attached file also creates a PageAttachment" do
    file = fixture_file_upload("sample_attachment.txt", "text/plain")

    assert_difference "PageAttachment.count", 1 do
      post area_pages_path(@area), params: {
        page: {
          title: "New page",
          page_attachments_attributes: {
            "0" => { label: "Contract", file: file }
          }
        }
      }
    end

    page_attachment = Page.find_by(title: "New page").page_attachments.sole
    assert_equal "Contract", page_attachment.label
    assert_equal "sample_attachment.txt", page_attachment.file.filename.to_s
  end

  test "updating a page can add a labeled attachment with a custom download filename" do
    file = fixture_file_upload("sample_attachment.txt", "text/plain")

    patch area_page_path(@area, @page), params: {
      page: {
        page_attachments_attributes: {
          "0" => { label: "Contract", download_filename: "renamed.txt", file: file }
        }
      }
    }

    page_attachment = @page.reload.page_attachments.find_by(label: "Contract")
    assert_equal "renamed.txt", page_attachment.effective_filename
  end

  test "updating a page can rename and relabel an existing attachment" do
    page_attachment = @page.page_attachments.create!(label: "Old label")
    page_attachment.file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample_attachment.txt")),
      filename: "sample_attachment.txt", content_type: "text/plain"
    )

    patch area_page_path(@area, @page), params: {
      page: {
        page_attachments_attributes: {
          "0" => { id: page_attachment.id, label: "New label", download_filename: "renamed.txt" }
        }
      }
    }

    assert_equal "New label", page_attachment.reload.label
    assert_equal "renamed.txt", page_attachment.effective_filename
  end

  test "updating a page can destroy an existing attachment" do
    page_attachment = @page.page_attachments.create!(label: "Old label")

    assert_difference "PageAttachment.count", -1 do
      patch area_page_path(@area, @page), params: {
        page: {
          page_attachments_attributes: {
            "0" => { id: page_attachment.id, _destroy: "1" }
          }
        }
      }
    end
  end
end
