class CreateTutorialSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorial_steps do |t|
      t.references :tutorial, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
