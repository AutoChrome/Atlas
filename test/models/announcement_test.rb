require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @announcement = Announcement.create!(title: "Test", starts_on: Date.current, ends_on: Date.current)
    @webhook = Webhook.create!(description: "Test", url: "https://example.com/hook", active: true)
  end

  test "publish! remembers which webhooks were actually sent to" do
    @announcement.publish!(webhook_ids: [ @webhook.id ])

    assert_equal [ @webhook.id ], @announcement.reload.published_webhook_ids
  end

  test "re-publishing to a different set replaces published_webhook_ids, not adds to it" do
    other_webhook = Webhook.create!(description: "Other", url: "https://example.com/hook", active: true)
    @announcement.publish!(webhook_ids: [ @webhook.id, other_webhook.id ])

    @announcement.publish!(webhook_ids: [ @webhook.id ])

    assert_equal [ @webhook.id ], @announcement.reload.published_webhook_ids
  end

  test "publish! enqueues an announcement.published delivery to the given webhooks" do
    assert_enqueued_with(job: WebhookDeliveryJob, args: [ WebhookDeliveryJob::PUBLISHED, @announcement.id, [ @webhook.id ] ]) do
      @announcement.publish!(webhook_ids: [ @webhook.id ])
    end
  end

  test "notify_webhooks_of_update! does nothing for a draft" do
    @announcement.update!(title: "Edited while still a draft")

    assert_no_enqueued_jobs(only: WebhookDeliveryJob) do
      @announcement.notify_webhooks_of_update!
    end
  end

  # content lives on the associated ActionText::RichText record
  # (has_rich_text), not a column on Announcement itself — a naive
  # `saved_changes?` guard would say nothing changed here and silently skip
  # notifying on the single most common kind of edit. Confirmed as an
  # actual bug during manual end-to-end testing before this test existed.
  test "notify_webhooks_of_update! fires for a content-only edit, not just a column on the row itself" do
    @announcement.publish!(webhook_ids: [ @webhook.id ])
    @announcement.update!(content: "<div>Updated content</div>")

    assert_enqueued_with(job: WebhookDeliveryJob, args: [ WebhookDeliveryJob::UPDATED, @announcement.id, [ @webhook.id ] ]) do
      @announcement.notify_webhooks_of_update!
    end
  end

  test "notify_webhooks_of_update! sends to the webhooks the announcement was actually published to" do
    other_webhook = Webhook.create!(description: "Other", url: "https://example.com/hook", active: true)
    @announcement.publish!(webhook_ids: [ @webhook.id ]) # other_webhook deliberately not included
    @announcement.update!(title: "Updated")

    assert_enqueued_with(job: WebhookDeliveryJob, args: [ WebhookDeliveryJob::UPDATED, @announcement.id, [ @webhook.id ] ]) do
      @announcement.notify_webhooks_of_update!
    end
  end

  test "notify_webhooks_of_deletion! does nothing for a draft" do
    assert_no_enqueued_jobs(only: WebhookDeliveryJob) do
      @announcement.notify_webhooks_of_deletion!
    end
  end

  test "notify_webhooks_of_deletion! captures title and url as plain values, for after the record is gone" do
    @announcement.publish!(webhook_ids: [ @webhook.id ])

    expected_url = Rails.application.routes.url_helpers.announcement_url(@announcement, host: ENV.fetch("SITE_ADDRESS", "localhost"))

    assert_enqueued_with(
      job: WebhookDeliveryJob,
      args: [ WebhookDeliveryJob::DELETED, @announcement.id, [ @webhook.id ], { title: @announcement.title, url: expected_url } ]
    ) do
      @announcement.notify_webhooks_of_deletion!
    end
  end
end
