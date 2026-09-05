class ApiToken < ApplicationRecord
  belongs_to :user
  has_many :api_token_areas, dependent: :destroy
  has_many :areas, through: :api_token_areas

  validates :name, presence: true

  before_validation :generate_token, on: :create

  # Only available on the in-memory instance that just generated it — never
  # persisted, and unrecoverable once this object is garbage collected. The
  # UI shows it once, at creation time, then only the digest is kept.
  attr_reader :plaintext_token

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.authenticate(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # Pages inherit their area's grant — there's no separate page-level scope.
  def authorized_for_area?(area)
    all_areas? || areas.include?(area)
  end

  private
    def generate_token
      @plaintext_token = SecureRandom.hex(32)
      self.token_digest = self.class.digest(@plaintext_token)
    end
end
