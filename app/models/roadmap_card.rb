class RoadmapCard < ApplicationRecord
  include Autocorrectable
  autocorrects :title, :description

  audited

  belongs_to :roadmap_section

  validates :title, presence: true

  scope :ordered, -> { order(:position) }

  delegate :project, to: :roadmap_section
end
