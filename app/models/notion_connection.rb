# A Notion "internal integration" (created in Notion at Settings >
# Connections > your connection) that pushes documentation INTO Atlas —
# see Integrations::NotionController for the inbound webhook this
# receives, and NotionSyncJob for what actually happens with an event.
#
# Two credentials, two different jobs:
# - integration_token: Notion's own API bearer token for THIS connection.
#   Used for outbound calls Atlas makes TO Notion (fetching a page's
#   content after a webhook says it changed).
# - verification_token: NOT something you generate or paste in here.
#   Notion sends it to the webhook URL below as a one-time handshake
#   payload once you create a subscription in Notion pointed at that URL
#   (see #receive_verification_token!) — from then on it's also the HMAC
#   key Notion signs every real event with (X-Notion-Signature), so it has
#   to be remembered, not just used once.
class NotionConnection < ApplicationRecord
  encrypts :integration_token
  encrypts :verification_token

  belongs_to :area

  audited except: %i[integration_token verification_token]

  before_validation :generate_webhook_token, on: :create

  validates :name, presence: true
  validates :integration_token, presence: true
  validates :webhook_token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  # True until Notion's one-time verification handshake has happened —
  # see Integrations::NotionController#webhook. Real events can't be
  # trusted (there's no signature to check yet) until this is false.
  def awaiting_verification?
    verification_token.blank?
  end

  def receive_verification_token!(token)
    update!(verification_token: token)
  end

  # `signature` is the raw X-Notion-Signature header value
  # ("sha256=<hex>"); `body` is the exact raw request body — re-serialized
  # JSON produces different bytes and fails this, same caveat as verifying
  # Atlas's own outbound webhook signatures (see the webhook integration
  # guide).
  def valid_signature?(body:, signature:)
    return false if awaiting_verification? || signature.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", verification_token, body)}"
    ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def regenerate_webhook_token!
    update!(webhook_token: SecureRandom.hex(32))
  end

  private
    def generate_webhook_token
      self.webhook_token ||= SecureRandom.hex(32)
    end
end
