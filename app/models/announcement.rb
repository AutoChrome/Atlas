class Announcement < ApplicationRecord
  include Autocorrectable
  autocorrects :title, rich_text: :content

  audited

  belongs_to :user, optional: true
  has_rich_text :content
  # Nullified, not destroyed — deleting an announcement shouldn't also wipe
  # its own delivery history (and this record's "announcement.deleted"
  # delivery is sent after it's already gone, so a delivery genuinely can
  # exist with no announcement to point back to — see WebhookDeliveryJob).
  has_many :webhook_deliveries, dependent: :nullify

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
    # Remembered so a later edit or deletion (see notify_webhooks_of_update!
    # / notify_webhooks_of_deletion!) reaches exactly these webhooks, not
    # whichever happen to be active by then — a webhook never told about
    # this announcement shouldn't suddenly hear it was "updated" or
    # "deleted", and one that WAS told shouldn't go quiet just because a
    # later re-publish (deliberately) left it unchecked.
    update!(published_webhook_ids: webhook_ids)
    WebhookDeliveryJob.perform_later(WebhookDeliveryJob::PUBLISHED, id, webhook_ids)

    Audited::Audit.create!(
      auditable: self,
      action: first_publish ? "publish" : "republish",
      user: by,
      audited_changes: { "webhook_ids" => webhook_ids },
      comment: "#{first_publish ? "Published" : "Re-published"} to #{webhook_ids.size} webhook#{"s" unless webhook_ids.size == 1}."
    )
  end

  # Called after a successful edit (AnnouncementsController#update) — tells
  # whichever webhooks actually received this announcement (see publish!)
  # that its content changed. A no-op for a draft (nothing to tell anyone,
  # published_webhook_ids is empty).
  #
  # Deliberately does NOT try to skip this when the save didn't change
  # anything detectable — `content` lives on the associated ActionText::RichText
  # record (has_rich_text), not a column on this row, so `saved_changes?`
  # here can be false even immediately after a real, saved content edit
  # (confirmed directly: editing only `content` and checking `saved_changes?`
  # right after returns false). Notifying on every successful update, even
  # an occasional genuine no-op resave, is a much smaller cost than silently
  # dropping a real content change.
  def notify_webhooks_of_update!
    return unless published?

    WebhookDeliveryJob.perform_later(WebhookDeliveryJob::UPDATED, id, published_webhook_ids)
  end

  # Called from AnnouncementsController#destroy BEFORE the record is
  # actually destroyed — the job runs in the background well after this
  # method returns, by which point the record is gone, so everything the
  # "deleted" payload needs is captured as plain values right now rather
  # than left for the job to look up later.
  def notify_webhooks_of_deletion!
    return unless published?

    WebhookDeliveryJob.perform_later(
      WebhookDeliveryJob::DELETED, id, published_webhook_ids,
      title: title, url: Rails.application.routes.url_helpers.announcement_url(self, host: ENV.fetch("SITE_ADDRESS", "localhost"))
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
