class WebhookDelivery < ApplicationRecord
  belongs_to :webhook
  belongs_to :announcement

  scope :ordered, -> { order(created_at: :desc) }
end
