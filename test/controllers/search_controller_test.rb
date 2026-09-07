require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "a blank query returns no results without touching search" do
    get search_path, params: { q: "" }, as: :json

    assert_response :success
    assert_equal [], JSON.parse(response.body)["results"]
  end

  # This is the exact failure mode that shipped: Chart's search_data grew a
  # table_names field before word_start declared it searchable, so querying
  # it raised "Bad mapping" — and because all four content types shared one
  # rescue, that one broken index took every type down with it, so a plain
  # page-title search returned nothing and looked like search was entirely
  # offline. Each type is now searched (and rescued) independently.
  test "a broken index for one content type still returns results for the others" do
    sign_in_as(users(:one))
    # Captured as a local, not called from inside the stub lambdas below —
    # define_singleton_method rebinds a lambda's `self` to the receiver
    # (Area/Chart/etc.) when it's invoked, so a fixture helper call inside
    # one of those lambdas would resolve against the wrong `self` entirely.
    area_one = areas(:one)

    with_search_stub(Chart, ->(*) { raise Searchkick::Error, "Bad mapping - run Chart.reindex" }) do
      with_search_stub(Page, ->(*) { [] }) do
        with_search_stub(Tutorial, ->(*) { [] }) do
          with_search_stub(Area, ->(*) { [ area_one ] }) do
            get search_path, params: { q: "anything" }, as: :json
          end
        end
      end
    end

    assert_response :success
    results = JSON.parse(response.body)["results"]
    assert_equal [ { "type" => "Area", "title" => area_one.name, "url" => area_path(area_one) } ], results
  end
end
