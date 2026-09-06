class AddConditionalStepsToTutorialTasks < ActiveRecord::Migration[8.1]
  def change
    # Each task can redirect the viewer to a different step depending on
    # whether they accepted or rejected it — nullable, since most tasks
    # don't branch and just fall through to the step's default next step.
    add_reference :tutorial_tasks, :next_step_if_accepted, foreign_key: { to_table: :tutorial_steps }
    add_reference :tutorial_tasks, :next_step_if_rejected, foreign_key: { to_table: :tutorial_steps }
  end
end
