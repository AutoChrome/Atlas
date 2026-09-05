class CreateAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :areas do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.references :parent, foreign_key: { to_table: :areas }
      t.boolean :public, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :areas, :slug, unique: true
    add_index :areas, :public
  end
end
