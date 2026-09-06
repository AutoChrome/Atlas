class CreateChartTables < ActiveRecord::Migration[8.1]
  def change
    create_table :chart_tables do |t|
      t.references :chart, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position_x, default: 0, null: false
      t.integer :position_y, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :chart_tables, [ :chart_id, :name ], unique: true
  end
end
