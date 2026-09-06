require "test_helper"

class TutorialStepTest < ActiveSupport::TestCase
  test "requires a title" do
    step = tutorial_steps(:one)
    step.title = nil
    assert_not step.valid?
  end

  test "default_next_step returns the next step in position order" do
    assert_equal tutorial_steps(:two), tutorial_steps(:one).default_next_step
  end

  test "default_next_step is nil for the last step in the tutorial" do
    assert_nil tutorial_steps(:two).default_next_step
  end

  test "decided_for? requires every task on the step to have a response" do
    step = tutorial_steps(:one)
    user = users(:one)

    assert step.decided_for?(user) # fixture responds to its one task for user :one
    assert_not step.decided_for?(users(:two))
  end

  test "decided_for? is false for a step with no tasks at all" do
    step = tutorial_steps(:other_tutorial_step)
    step.tutorial_tasks.destroy_all

    assert_not step.decided_for?(users(:one))
  end

  test "accepts multiple nested tasks in one save, positioned by submission order" do
    step = tutorial_steps(:other_tutorial_step)
    step.tutorial_tasks.destroy_all

    step.update!(
      tutorial_tasks_attributes: [
        { description: "First" },
        { description: "Second" },
        { description: "Third" }
      ]
    )

    assert_equal %w[First Second Third], step.tutorial_tasks.order(:position).pluck(:description)
    assert_equal [ 0, 1, 2 ], step.tutorial_tasks.order(:position).pluck(:position)
  end

  test "a blank nested task fieldset is silently dropped, not saved as empty" do
    step = tutorial_steps(:other_tutorial_step)
    initial_count = step.tutorial_tasks.count

    step.update!(tutorial_tasks_attributes: [ { description: "" } ])

    assert_equal initial_count, step.tutorial_tasks.count
  end

  test "marking a nested task for destruction removes it on save" do
    step = tutorial_steps(:other_tutorial_step)
    task = step.tutorial_tasks.first

    step.update!(tutorial_tasks_attributes: [ { id: task.id, _destroy: "1" } ])

    assert_not TutorialTask.exists?(task.id)
  end

  test "accepts a nested task with a conditional next step" do
    step = tutorial_steps(:other_tutorial_step)
    sibling_step = step.tutorial.tutorial_steps.create!(title: "Sibling", position: 1)

    step.update!(tutorial_tasks_attributes: [ { description: "Go", next_step_if_accepted_id: sibling_step.id } ])

    task = step.tutorial_tasks.last
    assert_equal sibling_step, task.next_step_if_accepted
  end
end
