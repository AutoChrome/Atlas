class Chart < ApplicationRecord
  include Autocorrectable
  autocorrects :title, :description

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :area

  audited

  belongs_to :area
  has_many :chart_tables, -> { order(:name) }, dependent: :destroy, inverse_of: :chart
  has_many :chart_columns, through: :chart_tables
  has_many :chart_relationships, dependent: :destroy, inverse_of: :chart

  # word_start on table_names/column_names too — without it, Searchkick
  # only builds a plain analyzed field for them (no prefix-matching
  # sub-mapping), and querying with match: :word_start against a field that
  # doesn't have one raises "Bad mapping" and takes the *entire* combined
  # search down with it (see SearchController) rather than just this model.
  # Deliberately just tables + columns, not indexes/notes/relationships —
  # those aren't what someone means by "find me the chart with a users
  # table," and notes in particular can carry pasted CHECK-constraint SQL
  # that would be noise here.
  searchkick word_start: [ :title, :description, :table_names, :column_names ]

  def search_data
    {
      title: title,
      description: description,
      table_names: chart_tables.pluck(:name).join(" "),
      column_names: chart_columns.pluck(:name).join(" "),
      area_name: area.name,
      public: publicly_visible?
    }
  end

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :area_id }

  scope :ordered, -> { order(:position, :title) }
  scope :public_only, -> { where(public: true) }

  def should_generate_new_friendly_id?
    title_changed? || super
  end

  # Visible without logging in if the chart itself, or its area (or an
  # ancestor area), has been made public.
  def publicly_visible?
    public? || area.publicly_visible?
  end
end
