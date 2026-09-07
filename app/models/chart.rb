class Chart < ApplicationRecord
  include Autocorrectable
  autocorrects :title, :description

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :area

  audited

  belongs_to :area
  has_many :chart_tables, -> { order(:name) }, dependent: :destroy, inverse_of: :chart
  has_many :chart_relationships, dependent: :destroy, inverse_of: :chart

  searchkick word_start: [ :title, :description ]

  def search_data
    {
      title: title,
      description: description,
      table_names: chart_tables.pluck(:name).join(" "),
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
