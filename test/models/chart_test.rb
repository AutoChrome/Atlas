require "test_helper"

class ChartTest < ActiveSupport::TestCase
  test "requires a title" do
    chart = charts(:one)
    chart.title = nil
    assert_not chart.valid?
  end

  test "slug is unique within an area" do
    # FriendlyId auto-resolves a colliding slug by regenerating a unique
    # one, so exercising the uniqueness validation itself means bypassing
    # that regeneration to force an actual collision through.
    dup = charts(:one).area.charts.new(title: "Something else", slug: charts(:one).slug)
    def dup.should_generate_new_friendly_id? = false

    assert_not dup.valid?
  end

  test "publicly_visible? follows its area when the chart itself isn't public" do
    chart = charts(:one)
    assert_not chart.publicly_visible?

    chart.area.update!(public: true)
    assert chart.reload.publicly_visible?
  end
end
