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
end
