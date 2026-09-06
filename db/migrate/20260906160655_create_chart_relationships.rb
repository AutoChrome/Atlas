class CreateChartRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :chart_relationships do |t|
      t.references :chart, null: false, foreign_key: true
      t.references :from_chart_column, null: false, foreign_key: { to_table: :chart_columns }
      t.references :to_chart_column, null: false, foreign_key: { to_table: :chart_columns }
      t.string :on_delete
      t.string :on_update

      t.timestamps
    end
  end
end
