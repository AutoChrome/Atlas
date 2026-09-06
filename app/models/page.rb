class Page < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :area

  audited

  belongs_to :area
  belongs_to :user, optional: true
  has_rich_text :content
  has_many_attached :attachments

  # word_start on both fields so a partial word like "onbo" matches
  # "Onboarding" whether it's in the title or the body content.
  searchkick word_start: [ :title, :content ]

  def search_data
    { title: title, content: content.to_plain_text, area_name: area.name, public: publicly_visible? }
  end

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :area_id }

  scope :ordered, -> { order(:position, :title) }
  scope :public_only, -> { where(public: true) }

  def should_generate_new_friendly_id?
    title_changed? || super
  end

  # Visible without logging in if the page itself, or its area (or an
  # ancestor area), has been made public.
  def publicly_visible?
    public? || area.publicly_visible?
  end
end
