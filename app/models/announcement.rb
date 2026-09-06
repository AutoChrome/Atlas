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
  # typo) re-sends to whichever webhooks are selected this time, but
  # published_at only gets set the first time. webhook_ids lets the caller
  # choose which active webhooks actually get this delivery (see
  # AnnouncementsController#publish, where that's a checkbox list) rather
  # than always fanning out to every one of them.
  #
  # The `audited` gem only records a change when a tracked attribute
  # actually changes, so a first publish gets an audit entry for free
  # (published_at goes from nil to a real time) but a re-publish wouldn't —
  # nothing on the record itself changes. This writes an explicit audit
  # entry either way, so "who (re-)published this, and to which webhooks"
  # is always in the trail, not just the first time.
  def publish!(webhook_ids: Webhook.active.pluck(:id), by: nil)
    first_publish = !published?
    update!(published_at: Time.current) if first_publish
    WebhookDeliveryJob.perform_later(id, webhook_ids)

    Audited::Audit.create!(
      auditable: self,
      action: first_publish ? "publish" : "republish",
      user: by,
      audited_changes: { "webhook_ids" => webhook_ids },
      comment: "#{first_publish ? "Published" : "Re-published"} to #{webhook_ids.size} webhook#{"s" unless webhook_ids.size == 1}."
    )
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
