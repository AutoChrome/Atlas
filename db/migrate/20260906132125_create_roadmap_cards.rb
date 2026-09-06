class CreateRoadmapCards < ActiveRecord::Migration[8.1]
  def change
    create_table :roadmap_cards do |t|
      t.references :roadmap_section, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :estimated_release_on
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
