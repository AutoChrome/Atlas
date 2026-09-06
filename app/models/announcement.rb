class Announcement < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  audited

  belongs_to :user, optional: true
  has_rich_text :content
  has_many :webhook_deliveries, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  def published?
    published_at.present?
  end

  # Safe to call more than once — publishing again (e.g. after fixing a
  # typo) re-sends to every active webhook, but published_at only gets set
  # the first time.
  def publish!
    update!(published_at: Time.current) unless published?
    WebhookDeliveryJob.perform_later(id)
  end
end
