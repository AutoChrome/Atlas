require "test_helper"

class NotionSyncDeliveryTest < ActiveSupport::TestCase
  setup do
    @connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))
  end

  test "defaults to received" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.content_updated")

    assert delivery.received?
  end

  test "mark_syncing! transitions to syncing" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.content_updated")

    delivery.mark_syncing!

    assert delivery.reload.syncing?
    assert_nil delivery.completed_at
  end

  test "mark_succeeded! records the resulting page and completed_at" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.content_updated")
    page = pages(:one)

    delivery.mark_succeeded!(page)

    delivery.reload
    assert delivery.succeeded?
    assert_equal page, delivery.page
    assert delivery.completed_at.present?
  end

  test "mark_failed! records a truncated error message and completed_at" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.content_updated")

    delivery.mark_failed!("boom " * 200)

    delivery.reload
    assert delivery.failed?
    assert delivery.error_message.length <= 500
    assert delivery.completed_at.present?
  end

  test "mark_ignored! records an optional reason and completed_at" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.deleted")

    delivery.mark_ignored!("not a handled event type")

    delivery.reload
    assert delivery.ignored?
    assert_equal "not a handled event type", delivery.error_message
    assert delivery.completed_at.present?
  end

  test "requires an event_type" do
    delivery = @connection.notion_sync_deliveries.new

    assert_not delivery.valid?
  end

  test "ordered puts the most recent delivery first" do
    older = @connection.notion_sync_deliveries.create!(event_type: "page.created", created_at: 2.days.ago)
    newer = @connection.notion_sync_deliveries.create!(event_type: "page.content_updated", created_at: 1.minute.ago)

    assert_equal [ newer, older ], @connection.notion_sync_deliveries.ordered.to_a
  end
end
