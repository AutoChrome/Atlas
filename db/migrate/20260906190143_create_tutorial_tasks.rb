class CreateTutorialTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorial_tasks do |t|
      t.references :tutorial_step, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
