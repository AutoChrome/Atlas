class CreateTutorialTaskCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorial_task_completions do |t|
      t.references :tutorial_task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tutorial_task_completions, [ :tutorial_task_id, :user_id ], unique: true
  end
end
