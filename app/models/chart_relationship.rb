class ChartRelationship < ApplicationRecord
  audited

  belongs_to :chart
  belongs_to :from_chart_column, class_name: "ChartColumn", inverse_of: :outgoing_relationships
  belongs_to :to_chart_column, class_name: "ChartColumn", inverse_of: :incoming_relationships

  delegate :chart_table, to: :from_chart_column, prefix: :from
  delegate :chart_table, to: :to_chart_column, prefix: :to
end
