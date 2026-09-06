require "test_helper"

class TutorialTaskTest < ActiveSupport::TestCase
  test "requires a description" do
    task = tutorial_tasks(:one)
    task.description = nil
    assert_not task.valid?
  end

  test "accepted_for?/rejected_for?/decided_for? read that specific user's response" do
    task = tutorial_tasks(:one) # fixture: user :one accepted this task

    assert task.accepted_for?(users(:one))
    assert_not task.rejected_for?(users(:one))
    assert task.decided_for?(users(:one))

    assert_not task.accepted_for?(users(:two))
    assert_not task.decided_for?(users(:two))
    assert_not task.decided_for?(nil)
  end

  test "rejected_for? is true once a user's response is a cross" do
    task = tutorial_tasks(:two)
    task.tutorial_task_responses.create!(user: users(:two), accepted: false)

    assert task.rejected_for?(users(:two))
    assert_not task.accepted_for?(users(:two))
  end

  test "next_step_if_accepted/rejected must belong to the same tutorial as the task's own step" do
    foreign_step = tutorial_steps(:other_tutorial_step) # belongs to tutorials(:two)
    task = tutorial_tasks(:one) # belongs to tutorials(:one) via tutorial_steps(:one)

    task.next_step_if_accepted = foreign_step
    assert_not task.valid?

    task.next_step_if_accepted = nil
    task.next_step_if_rejected = foreign_step
    assert_not task.valid?
  end

  test "next_step_if_accepted/rejected within the same tutorial are valid" do
    task = tutorial_tasks(:one)
    task.next_step_if_accepted = tutorial_steps(:two)

    assert task.valid?
  end

  test "deleting a targeted step nullifies the task's conditional reference instead of destroying it" do
    task = tutorial_tasks(:one)
    task.update!(next_step_if_accepted: tutorial_steps(:two))

    tutorial_steps(:two).destroy

    assert_nil task.reload.next_step_if_accepted_id
  end
end
