class Announcement < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  audited

  belongs_to :user, optional: true
  has_rich_text :content
  has_many :webhook_deliveries, dependent: :destroy

  validates :title, presence: true
  validate :starts_on_is_present_and_valid
  validate :ends_on_is_present_and_valid
  validate :ends_on_not_before_starts_on

  scope :ordered, -> { order(created_at: :desc) }
  scope :published, -> { where.not(published_at: nil).order(published_at: :desc) }

  def published?
    published_at.present?
  end

  # One row per webhook — its most recent delivery attempt, not the full
  # history (that's on the announcement's own page). Re-publishing can leave
  # more than one delivery per webhook, so this is what "did it go out
  # successfully" actually means at a glance.
  def latest_deliveries
    webhook_deliveries.group_by(&:webhook_id).values.map { |deliveries| deliveries.max_by(&:created_at) }
  end

  # Safe to call more than once — publishing again (e.g. after fixing a
  # typo) re-sends to every active webhook, but published_at only gets set
  # the first time.
  def publish!
    update!(published_at: Time.current) unless published?
    WebhookDeliveryJob.perform_later(id)
  end

  private
    # A date column silently casts an unparseable string (e.g. "next tuesday",
    # "13/32/2026") to nil rather than raising, so a plain `presence` check
    # can't tell a typo'd date apart from the field being left blank.
    # Comparing against the raw, pre-cast input distinguishes the two so API
    # callers get an error that actually points at the problem.
    def starts_on_is_present_and_valid
      validate_date_field(:starts_on)
    end

    def ends_on_is_present_and_valid
      validate_date_field(:ends_on)
    end

    def validate_date_field(attribute)
      return if public_send(attribute).present?

      if public_send(:"#{attribute}_before_type_cast").blank?
        errors.add(attribute, "can't be blank")
      else
        errors.add(attribute, "must be a valid date (YYYY-MM-DD)")
      end
    end

    def ends_on_not_before_starts_on
      return if starts_on.blank? || ends_on.blank?

      errors.add(:ends_on, "can't be before the start date") if ends_on < starts_on
    end
end
