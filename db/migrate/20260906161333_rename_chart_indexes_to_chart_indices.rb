class RenameChartIndexesToChartIndices < ActiveRecord::Migration[8.1]
  def change
    # ChartIndex pluralizes to "chart_indices" by Rails' default inflector
    # (irregular: index -> indices), but the original migration created
    # "chart_indexes" — rename the table to match what ActiveRecord actually
    # looks up.
    rename_table :chart_indexes, :chart_indices
  end
end
