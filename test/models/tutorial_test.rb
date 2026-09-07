require "test_helper"

class TutorialTest < ActiveSupport::TestCase
  test "requires a title" do
    tutorial = tutorials(:one)
    tutorial.title = nil
    assert_not tutorial.valid?
  end

  test "publicly_visible? follows its area when not itself public" do
    tutorial = tutorials(:one)
    assert_not tutorial.publicly_visible?

    tutorial.area.update!(public: true)
    assert tutorial.reload.publicly_visible?
  end

  test "linear? is true until any task branches to a different step" do
    tutorial = tutorials(:one)
    assert tutorial.linear?

    tutorial_tasks(:one).update!(next_step_if_accepted: tutorial_steps(:two))
    assert_not tutorial.reload.linear?
  end

  test "search_data indexes every step's title and content, not just the tutorial's own description" do
    data = tutorials(:one).search_data

    assert_includes data[:steps_content], "Step One"
    assert_includes data[:steps_content], "Step Two"
  end

  test "total_tasks_count and answered_tasks_count only count this tutorial's own steps" do
    tutorial = tutorials(:one)
    assert_equal 2, tutorial.total_tasks_count # tasks :one and :two, both under tutorial :one's steps

    # Fixture already responds to task :one for user :one.
    assert_equal 1, tutorial.answered_tasks_count(users(:one))
    assert_equal 0, tutorial.answered_tasks_count(users(:two))

    tutorial_tasks(:two).tutorial_task_responses.create!(user: users(:one), accepted: false)
    assert_equal 2, tutorial.answered_tasks_count(users(:one))
  end
end
