class Webhook < ApplicationRecord
  # Needs to be read back later to sign outgoing requests, so it's encrypted
  # at rest (config/initializers/active_record_encryption.rb) rather than
  # hashed like ApiToken#token_digest, which is only ever compared.
  encrypts :secret

  has_many :webhook_deliveries, dependent: :destroy

  audited except: [:secret]

  before_validation :generate_secret, on: :create

  validates :description, presence: true
  validates :url, presence: true
  validate :url_must_be_http_or_https

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:description) }

  def regenerate_secret!
    update!(secret: SecureRandom.hex(32))
  end

  private
    def generate_secret
      self.secret ||= SecureRandom.hex(32)
    end

    def url_must_be_http_or_https
      return if url.blank?

      parsed = URI.parse(url)
      errors.add(:url, "must be a valid http:// or https:// URL") unless parsed.is_a?(URI::HTTP) && parsed.host.present?
    rescue URI::InvalidURIError
      errors.add(:url, "must be a valid http:// or https:// URL")
    end
end
