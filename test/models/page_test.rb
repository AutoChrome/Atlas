require "test_helper"

class PageTest < ActiveSupport::TestCase
  setup do
    @area = areas(:one)
    @connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)
  end

  test "current_notion_sync is nil for a page that isn't Notion-synced" do
    page = @area.pages.create!(title: "Plain page")

    assert_nil page.current_notion_sync
  end

  test "current_notion_sync finds the latest delivery by Notion page ID, even before the Atlas page is linked" do
    # Simulates a brand new page's first sync — the delivery exists (and is
    # "syncing") before NotionSyncJob has created the Atlas page at all, so
    # there's nothing yet to link it to via the page_id foreign key.
    delivery = @connection.notion_sync_deliveries.create!(
      event_type: "page.created", notion_page_id: "notion-abc", status: :syncing
    )
    page = @area.pages.new(title: "In progress", notion_page_id: "notion-abc")

    assert_equal delivery, page.current_notion_sync
  end

  test "notion_syncing? is true only while the latest delivery is still syncing" do
    page = @area.pages.create!(title: "Synced page", notion_page_id: "notion-abc")
    delivery = @connection.notion_sync_deliveries.create!(
      event_type: "page.content_updated", notion_page_id: "notion-abc", status: :syncing
    )

    assert page.notion_syncing?

    delivery.mark_succeeded!(page)

    assert_not page.reload.notion_syncing?
  end

  test "current_notion_sync returns the most recent delivery, not the first" do
    page = @area.pages.create!(title: "Synced page", notion_page_id: "notion-abc")
    @connection.notion_sync_deliveries.create!(
      event_type: "page.created", notion_page_id: "notion-abc", status: :succeeded, completed_at: 1.day.ago
    )
    latest = @connection.notion_sync_deliveries.create!(
      event_type: "page.content_updated", notion_page_id: "notion-abc", status: :failed, completed_at: 1.minute.ago
    )

    assert_equal latest, page.current_notion_sync
  end
end
