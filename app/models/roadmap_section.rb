class RoadmapSection < ApplicationRecord
  include Autocorrectable
  autocorrects :name

  audited

  belongs_to :project
  has_many :roadmap_cards, -> { order(:position) }, dependent: :destroy, inverse_of: :roadmap_section

  validates :name, presence: true

  scope :ordered, -> { order(:position) }
end
