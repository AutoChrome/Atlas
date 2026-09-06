class CreateTutorials < ActiveRecord::Migration[8.1]
  def change
    create_table :tutorials do |t|
      t.references :area, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :public, default: false, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :tutorials, [ :area_id, :slug ], unique: true
    add_index :tutorials, :public
  end
end
