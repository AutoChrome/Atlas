class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :area, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.references :user, null: false, foreign_key: true
      t.boolean :public, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :pages, [ :area_id, :slug ], unique: true
    add_index :pages, :public
  end
end
