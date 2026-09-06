class ChartTable < ApplicationRecord
  include Autocorrectable
  autocorrects :notes

  audited

  belongs_to :chart
  has_many :chart_columns, -> { order(:position) }, dependent: :destroy, inverse_of: :chart_table
  has_many :chart_indices, dependent: :destroy, inverse_of: :chart_table

  validates :name, presence: true, uniqueness: { scope: :chart_id, case_sensitive: false }

  # All indexes on this table, split into their component column names —
  # used by ChartColumn#indexed? to answer "is this column part of any
  # index" (single-column or composite) without ChartColumn needing its
  # own redundant, driftable boolean.
  def indexed_column_names
    chart_indices.flat_map { |index| index.columns.to_s.split(",").map(&:strip) }.to_set
  end
end
