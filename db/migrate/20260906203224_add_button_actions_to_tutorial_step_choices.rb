class AddButtonActionsToTutorialStepChoices < ActiveRecord::Migration[8.1]
  def change
    # `stay` — a button that performs its action (below) without navigating
    # anywhere, distinct from a blank target (which means "end of tutorial").
    add_column :tutorial_step_choices, :stay, :boolean, default: false, null: false

    # A button can optionally mark one of its OWN step's tasks as done —
    # independent of whichever navigation (or `stay`) it also performs.
    # Nullable: most buttons don't do this. References tutorial_tasks, not a
    # "completes_tutorial_tasks" table, so `to_table:` is required here.
    add_reference :tutorial_step_choices, :completes_tutorial_task, foreign_key: { to_table: :tutorial_tasks }
  end
end
