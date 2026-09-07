class RemovePositionFromChartTables < ActiveRecord::Migration[8.1]
  def change
    # Dropping the free-form canvas (drag positioning, connecting lines)
    # for a plain grid the browser lays out itself — nothing reads these
    # any more, and a real layout doesn't need a stored x/y at all.
    remove_column :chart_tables, :position_x, :integer, default: 0, null: false
    remove_column :chart_tables, :position_y, :integer, default: 0, null: false
  end
end
