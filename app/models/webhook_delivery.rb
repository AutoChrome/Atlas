class WebhookDelivery < ApplicationRecord
  belongs_to :webhook
  # Optional so a delivery can outlive the announcement it was about — an
  # "announcement.deleted" delivery is, by definition, sent after the
  # announcement is already gone (see WebhookDeliveryJob), and existing
  # delivery history for a since-deleted announcement is nullified rather
  # than destroyed with it (see Announcement's has_many).
  belongs_to :announcement, optional: true

  scope :ordered, -> { order(created_at: :desc) }
end
