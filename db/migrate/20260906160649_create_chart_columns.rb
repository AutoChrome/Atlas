class CreateChartColumns < ActiveRecord::Migration[8.1]
  def change
    create_table :chart_columns do |t|
      t.references :chart_table, null: false, foreign_key: true
      t.string :name, null: false
      t.string :data_type
      t.integer :position, default: 0, null: false
      t.boolean :primary_key, default: false, null: false
      t.boolean :nullable, default: true, null: false
      t.boolean :unique, default: false, null: false
      t.string :default_value

      t.timestamps
    end

    add_index :chart_columns, [ :chart_table_id, :name ], unique: true
  end
end
