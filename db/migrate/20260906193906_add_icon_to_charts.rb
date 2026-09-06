class AddIconToCharts < ActiveRecord::Migration[8.1]
  def change
    add_column :charts, :icon, :string
  end
end
