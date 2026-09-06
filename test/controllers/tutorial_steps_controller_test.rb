require "test_helper"

class TutorialStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = areas(:one)
    @tutorial = tutorials(:one)
    sign_in_as(users(:one))
  end

  test "new builds one default task fieldset so a plain step needs no extra clicks" do
    get new_area_tutorial_tutorial_step_path(@area, @tutorial)

    assert_response :success
    assert_select "input[name=?][value=?]", "tutorial_step[tutorial_tasks_attributes][0][description]", "Complete this step"
  end

  test "create saves the step with multiple nested tasks in one request" do
    assert_difference "TutorialStep.count", 1 do
      assert_difference "TutorialTask.count", 2 do
        post area_tutorial_tutorial_steps_path(@area, @tutorial), params: {
          tutorial_step: {
            title: "New Step",
            tutorial_tasks_attributes: {
              "0" => { description: "First" },
              "1" => { description: "Second" }
            }
          }
        }
      end
    end

    step = TutorialStep.find_by(title: "New Step")
    assert_equal 2, step.tutorial_tasks.count
    assert_redirected_to area_tutorial_path(@area, @tutorial)
  end

  test "create accepts a task with a conditional next step" do
    other_step = tutorial_steps(:two)

    post area_tutorial_tutorial_steps_path(@area, @tutorial), params: {
      tutorial_step: {
        title: "New Step",
        tutorial_tasks_attributes: {
          "0" => { description: "Do the thing", next_step_if_accepted_id: other_step.id }
        }
      }
    }

    step = TutorialStep.find_by(title: "New Step")
    assert_equal other_step, step.tutorial_tasks.sole.next_step_if_accepted
  end

  test "create accepts a task with a hint" do
    post area_tutorial_tutorial_steps_path(@area, @tutorial), params: {
      tutorial_step: {
        title: "New Step",
        tutorial_tasks_attributes: {
          "0" => { description: "Do the thing", hint: "Look under Settings" }
        }
      }
    }

    step = TutorialStep.find_by(title: "New Step")
    assert_equal "Look under Settings", step.tutorial_tasks.sole.hint
  end

  test "update can remove an existing task via the nested _destroy flag" do
    step = tutorial_steps(:one)
    task = step.tutorial_tasks.first

    assert_difference "TutorialTask.count", -1 do
      patch area_tutorial_tutorial_step_path(@area, @tutorial, step), params: {
        tutorial_step: { title: step.title, tutorial_tasks_attributes: { "0" => { id: task.id, _destroy: "1" } } }
      }
    end

    assert_not TutorialTask.exists?(task.id)
  end
end
