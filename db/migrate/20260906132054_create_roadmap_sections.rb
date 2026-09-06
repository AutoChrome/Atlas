class CreateRoadmapSections < ActiveRecord::Migration[8.1]
  def change
    create_table :roadmap_sections do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
