class ChartColumn < ApplicationRecord
  include Autocorrectable
  autocorrects :name

  audited

  belongs_to :chart_table
  has_many :outgoing_relationships, class_name: "ChartRelationship", foreign_key: :from_chart_column_id,
                                     dependent: :destroy, inverse_of: :from_chart_column
  has_many :incoming_relationships, class_name: "ChartRelationship", foreign_key: :to_chart_column_id,
                                     dependent: :destroy, inverse_of: :to_chart_column

  validates :name, presence: true, uniqueness: { scope: :chart_table_id, case_sensitive: false }

  scope :ordered, -> { order(:position) }

  # Derived, not stored — the relationship itself is the source of truth
  # (it's also what's needed to draw the connecting line), so there's
  # nothing here that could drift out of sync with it.
  def foreign_key?
    outgoing_relationships.any?
  end

  # Derived from the table's indexes rather than a stored flag, so a
  # column can't stay marked "indexed" after its last covering index is
  # deleted (or vice versa). Covers both single-column and composite
  # index membership.
  def indexed?
    chart_table.indexed_column_names.include?(name)
  end
end
