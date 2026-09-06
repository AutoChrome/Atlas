class CreateChartIndexes < ActiveRecord::Migration[8.1]
  def change
    create_table :chart_indexes do |t|
      t.references :chart_table, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :unique, default: false, null: false
      t.string :columns, null: false

      t.timestamps
    end
  end
end
