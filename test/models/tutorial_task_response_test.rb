require "test_helper"

class TutorialTaskResponseTest < ActiveSupport::TestCase
  test "a user can only respond to the same task once" do
    dup = TutorialTaskResponse.new(tutorial_task: tutorial_tasks(:one), user: users(:one), accepted: true)
    assert_not dup.valid?
  end

  test "different users can each respond to the same task" do
    response = TutorialTaskResponse.new(tutorial_task: tutorial_tasks(:one), user: users(:two), accepted: false)
    assert response.valid?
  end
end
