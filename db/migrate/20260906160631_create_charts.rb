class CreateCharts < ActiveRecord::Migration[8.1]
  def change
    create_table :charts do |t|
      t.references :area, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :public, default: false, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :charts, [ :area_id, :slug ], unique: true
    add_index :charts, :public
  end
end
