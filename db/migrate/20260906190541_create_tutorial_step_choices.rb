class CreateTutorialStepChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorial_step_choices do |t|
      # The step this choice is presented on (the "from" side of the edge).
      t.references :tutorial_step, null: false, foreign_key: true

      # Exactly one of these two (or neither, meaning "end of tutorial") is
      # set — a plain in-tutorial branch vs. handing off into a whole other
      # tutorial (entered at its own first step). Enforced in the model,
      # not the DB, to keep this simple.
      t.references :next_tutorial_step, foreign_key: { to_table: :tutorial_steps }
      t.references :next_tutorial, foreign_key: { to_table: :tutorials }

      t.string :label
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
