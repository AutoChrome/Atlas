class Area < ApplicationRecord
  include Autocorrectable
  autocorrects :name, :description

  extend FriendlyId
  friendly_id :name, use: :slugged

  audited

  belongs_to :parent, class_name: "Area", optional: true
  has_many :children, class_name: "Area", foreign_key: :parent_id, dependent: :destroy
  has_many :pages, -> { order(:position) }, dependent: :destroy

  # word_start on both fields so a partial word like "onbo" matches
  # "Onboarding" whether it's in the name or the description.
  searchkick word_start: [:name, :description]

  def search_data
    { name: name, description: description, public: publicly_visible? }
  end

  validates :name, presence: true
  validates :slug, uniqueness: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :public_only, -> { where(public: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :ordered_alphabetically, -> { order(:name) }

  def self.ordered_by(sort_mode)
    sort_mode == "alphabetical" ? ordered_alphabetically : ordered
  end

  def should_generate_new_friendly_id?
    name_changed? || super
  end

  # An area is visible without logging in if it (or an ancestor) is public.
  def publicly_visible?
    public? || parent&.publicly_visible? || false
  end
end
