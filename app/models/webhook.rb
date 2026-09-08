class Webhook < ApplicationRecord
  # Needs to be read back later to sign outgoing requests, so it's encrypted
  # at rest (config/initializers/active_record_encryption.rb) rather than
  # hashed like ApiToken#token_digest, which is only ever compared.
  encrypts :secret

  has_many :webhook_deliveries, dependent: :destroy

  # What WebhookDeliveryJob sends as the announcement's `content` field —
  # see RichTextPayload for what each actually produces. "html" is the
  # full rich text, attachments (tables, callouts, images) expanded to
  # their real markup; "plain_text" strips all formatting down to text,
  # for a receiver that can't (or shouldn't) handle HTML at all.
  enum :content_format, { html: 0, plain_text: 1 }, default: :html

  audited except: [ :secret ]

  before_validation :generate_secret, on: :create

  validates :description, presence: true
  validates :url, presence: true
  validate :url_must_be_http_or_https
  validate :custom_parameters_must_be_a_flat_object

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:description) }

  def regenerate_secret!
    update!(secret: SecureRandom.hex(32))
  end

  # The admin form edits this rather than the jsonb column directly — a
  # bare `text_area :custom_parameters` would round-trip through Ruby's
  # Hash#to_s (`{"team"=>"platform"}`), which isn't valid JSON an admin
  # could copy back in, and on submit ActiveRecord would try to cast
  # whatever string they typed straight into the jsonb column with no
  # chance to show a friendly error first. When the submitted text isn't
  # valid JSON, custom_parameters is left untouched and the invalid text
  # is held onto (@custom_parameters_json_invalid) purely so the getter can
  # hand the form back exactly what the admin typed, rather than silently
  # reverting to the last-saved value and losing their edit.
  def custom_parameters_json
    return @custom_parameters_json_invalid if @custom_parameters_json_invalid
    custom_parameters.present? ? JSON.pretty_generate(custom_parameters) : ""
  end

  def custom_parameters_json=(value)
    if value.blank?
      self.custom_parameters = {}
    else
      self.custom_parameters = JSON.parse(value)
    end
    @custom_parameters_json_invalid = nil
  rescue JSON::ParserError
    @custom_parameters_json_invalid = value
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

    # Deliberately flat (string/number/boolean/null values only, no nested
    # objects or arrays) — the whole point is "attach some simple data to
    # every request," not a second content model to maintain alongside the
    # announcement's own fields.
    def custom_parameters_must_be_a_flat_object
      if @custom_parameters_json_invalid
        errors.add(:custom_parameters, "must be valid JSON")
        return
      end

      return if custom_parameters.blank?

      unless custom_parameters.is_a?(Hash)
        errors.add(:custom_parameters, "must be a JSON object, e.g. {\"team\": \"platform\"}")
        return
      end

      custom_parameters.each do |key, value|
        next if value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false

        errors.add(:custom_parameters, "value for \"#{key}\" must be a string, number, boolean, or null — nested objects and arrays aren't supported")
      end
    end
end
