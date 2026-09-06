class Project < ApplicationRecord
  include Autocorrectable
  autocorrects :name, :description

  extend FriendlyId
  friendly_id :name, use: :slugged

  audited

  has_many :roadmap_sections, -> { order(:position) }, dependent: :destroy, inverse_of: :project

  validates :name, presence: true
  validates :slug, uniqueness: true

  def should_generate_new_friendly_id?
    name_changed? || super
  end
end
