# One row per inbound request Integrations::NotionController received —
# a verification handshake, an event Atlas actually acts on, one it
# doesn't, or a rejected/bad-signature attempt. This is the only place
# "did Notion even contact us, and what happened" is answerable from
# inside Atlas, short of reading server logs directly.
class NotionSyncDelivery < ApplicationRecord
  belongs_to :notion_connection
  belongs_to :page, optional: true

  enum :status, { received: 0, syncing: 1, succeeded: 2, failed: 3, ignored: 4 }, default: :received

  validates :event_type, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  def mark_syncing!
    update!(status: :syncing)
  end

  def mark_succeeded!(page)
    update!(status: :succeeded, page: page, completed_at: Time.current)
  end

  def mark_failed!(error_message)
    update!(status: :failed, error_message: error_message.to_s.first(500), completed_at: Time.current)
  end

  def mark_ignored!(reason = nil)
    update!(status: :ignored, error_message: reason, completed_at: Time.current)
  end
end
