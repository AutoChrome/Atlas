class CreateApiTokenAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :api_token_areas do |t|
      t.references :api_token, null: false, foreign_key: true
      t.references :area, null: false, foreign_key: true

      t.timestamps
    end
    add_index :api_token_areas, [:api_token_id, :area_id], unique: true
  end
end
