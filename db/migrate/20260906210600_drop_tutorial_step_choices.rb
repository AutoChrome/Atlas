class DropTutorialStepChoices < ActiveRecord::Migration[8.1]
  def change
    # Replaced by per-task accept/reject branching (next_step_if_accepted_id
    # / next_step_if_rejected_id on tutorial_tasks) — user-authored choice
    # buttons and cross-tutorial hand-offs are gone entirely.
    drop_table :tutorial_step_choices do |t|
      t.bigint "completes_tutorial_task_id"
      t.datetime "created_at", null: false
      t.string "label"
      t.bigint "next_tutorial_id"
      t.bigint "next_tutorial_step_id"
      t.integer "position", default: 0, null: false
      t.boolean "stay", default: false, null: false
      t.bigint "tutorial_step_id", null: false
      t.datetime "updated_at", null: false
    end
  end
end
