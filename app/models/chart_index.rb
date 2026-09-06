class ChartIndex < ApplicationRecord
  audited

  belongs_to :chart_table

  validates :name, presence: true
  validates :columns, presence: true

  def column_names
    columns.to_s.split(",").map(&:strip)
  end
end
