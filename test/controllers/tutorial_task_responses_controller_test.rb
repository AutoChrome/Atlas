require "test_helper"

class TutorialTaskResponsesControllerTest < ActionDispatch::IntegrationTest
  test "create requires sign-in" do
    post area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
      params: { tutorial_task_id: tutorial_tasks(:two).id, accepted: "true" }

    assert_redirected_to new_session_path
  end

  test "create rejects a tutorial_task_id belonging to a different tutorial" do
    sign_in_as(users(:one))
    foreign_task = tutorial_tasks(:other_tutorial_task) # belongs to tutorials(:two)

    assert_no_difference "TutorialTaskResponse.count" do
      post area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
        params: { tutorial_task_id: foreign_task.id, accepted: "true" }
    end

    assert_response :not_found
  end

  test "create is idempotent for the same decision on a task that belongs to this tutorial" do
    sign_in_as(users(:two))

    assert_difference "TutorialTaskResponse.count", 1 do
      post area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
        params: { tutorial_task_id: tutorial_tasks(:two).id, accepted: "true" }
    end

    assert_no_difference "TutorialTaskResponse.count" do
      post area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
        params: { tutorial_task_id: tutorial_tasks(:two).id, accepted: "true" }
    end
  end

  test "create overwrites a previous decision rather than creating a second row" do
    sign_in_as(users(:one)) # fixture already accepted tutorial_tasks(:one)

    assert_no_difference "TutorialTaskResponse.count" do
      post area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
        params: { tutorial_task_id: tutorial_tasks(:one).id, accepted: "false" }
    end

    assert_equal false, tutorial_tasks(:one).tutorial_task_responses.find_by(user: users(:one)).accepted
  end

  test "destroy only removes the current user's own response" do
    sign_in_as(users(:one))

    assert_difference "TutorialTaskResponse.count", -1 do
      delete area_tutorial_task_responses_path(areas(:one), tutorials(:one)),
        params: { tutorial_task_id: tutorial_tasks(:one).id }
    end
  end

  test "reset_all requires sign-in" do
    delete area_tutorial_progress_path(areas(:one), tutorials(:one))

    assert_redirected_to new_session_path
  end

  test "reset_all clears every one of the current user's responses across the tutorial, and no one else's" do
    sign_in_as(users(:one)) # fixture already responded to tutorial_tasks(:one)
    tutorial_tasks(:two).tutorial_task_responses.create!(user: users(:one), accepted: false)
    tutorial_tasks(:two).tutorial_task_responses.create!(user: users(:two), accepted: true)

    assert_difference "TutorialTaskResponse.count", -2 do
      delete area_tutorial_progress_path(areas(:one), tutorials(:one))
    end

    assert TutorialTaskResponse.exists?(user: users(:two))
  end

  test "reset_all does not touch responses on a different tutorial" do
    sign_in_as(users(:two))
    foreign_task = tutorial_tasks(:other_tutorial_task) # belongs to tutorials(:two) via tutorial_steps(:other_tutorial_step)
    foreign_task.tutorial_task_responses.create!(user: users(:two), accepted: true)

    assert_no_difference "TutorialTaskResponse.count" do
      delete area_tutorial_progress_path(areas(:one), tutorials(:one))
    end
  end
end
