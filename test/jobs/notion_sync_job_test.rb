require "test_helper"

class NotionSyncJobTest < ActiveJob::TestCase
  setup do
    @area = areas(:one)
    @connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)
  end

  # Stubs NotionClient's own HTTP calls (same reasoning as
  # WebhookDeliveryJobTest stubbing #post — no mocking gem for what's
  # ultimately one class's two methods) so this tests NotionSyncJob's own
  # logic, not a real call to api.notion.com. Captures the real
  # implementations first and restores them via define_method, not
  # remove_method — remove_method would delete them outright rather than
  # reveal whatever was "underneath", since define_method replaces a
  # same-named method in place instead of layering over it.
  def stub_notion_client(page:, blocks:)
    original_retrieve_page = NotionClient.instance_method(:retrieve_page)
    original_retrieve_block_children = NotionClient.instance_method(:retrieve_block_children)

    NotionClient.define_method(:retrieve_page) { |_page_id| page }
    NotionClient.define_method(:retrieve_block_children) { |_block_id| blocks }
    yield
  ensure
    NotionClient.define_method(:retrieve_page, original_retrieve_page)
    NotionClient.define_method(:retrieve_block_children, original_retrieve_block_children)
  end

  def notion_page(title:, archived: false, in_trash: false)
    {
      "archived" => archived,
      "in_trash" => in_trash,
      "properties" => {
        "title" => { "type" => "title", "title" => [ { "plain_text" => title } ] }
      }
    }
  end

  test "creates a new page in the connection's area" do
    stub_notion_client(
      page: notion_page(title: "Deploying to production"),
      blocks: [ { "type" => "paragraph", "paragraph" => { "rich_text" => [ { "plain_text" => "Step one", "annotations" => {}, "href" => nil } ] } } ]
    ) do
      assert_difference "@area.pages.count", 1 do
        NotionSyncJob.perform_now(@connection.id, "notion-page-123")
      end
    end

    page = @area.pages.find_by(notion_page_id: "notion-page-123")
    assert_equal "Deploying to production", page.title
    assert_match "Step one", page.content.to_s
  end

  test "new pages are created private, never public automatically" do
    stub_notion_client(page: notion_page(title: "Test"), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123")
    end

    assert_not @area.pages.find_by(notion_page_id: "notion-page-123").public?
  end

  test "updates the same Atlas page on a second sync, rather than creating a duplicate" do
    stub_notion_client(page: notion_page(title: "Original title"), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123")
    end

    stub_notion_client(page: notion_page(title: "Updated title"), blocks: []) do
      assert_no_difference "@area.pages.count" do
        NotionSyncJob.perform_now(@connection.id, "notion-page-123")
      end
    end

    page = @area.pages.find_by(notion_page_id: "notion-page-123")
    assert_equal "Updated title", page.title
  end

  test "leaves an existing page's public flag alone on update, doesn't revert a manual change" do
    stub_notion_client(page: notion_page(title: "Original"), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123")
    end
    @area.pages.find_by(notion_page_id: "notion-page-123").update!(public: true)

    stub_notion_client(page: notion_page(title: "Updated"), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123")
    end

    assert @area.pages.find_by(notion_page_id: "notion-page-123").public?
  end

  test "does nothing for an archived or trashed Notion page" do
    stub_notion_client(page: notion_page(title: "Test", in_trash: true), blocks: []) do
      assert_no_difference "@area.pages.count" do
        NotionSyncJob.perform_now(@connection.id, "notion-page-123")
      end
    end
  end

  test "does nothing when the connection is inactive" do
    @connection.update!(active: false)

    assert_no_difference "@area.pages.count" do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123")
    end
  end

  test "does nothing when the connection no longer exists" do
    assert_no_difference "@area.pages.count" do
      NotionSyncJob.perform_now(-1, "notion-page-123")
    end
  end

  test "marks the delivery succeeded and links the resulting page" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.created", notion_page_id: "notion-page-123")

    stub_notion_client(page: notion_page(title: "Test"), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123", delivery.id)
    end

    delivery.reload
    assert delivery.succeeded?
    assert_equal @area.pages.find_by(notion_page_id: "notion-page-123"), delivery.page
    assert delivery.completed_at.present?
  end

  test "marks the delivery ignored for an archived or trashed Notion page" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.created", notion_page_id: "notion-page-123")

    stub_notion_client(page: notion_page(title: "Test", archived: true), blocks: []) do
      NotionSyncJob.perform_now(@connection.id, "notion-page-123", delivery.id)
    end

    assert delivery.reload.ignored?
  end

  test "marks the delivery failed when the connection is inactive" do
    @connection.update!(active: false)
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.created", notion_page_id: "notion-page-123")

    NotionSyncJob.perform_now(@connection.id, "notion-page-123", delivery.id)

    delivery.reload
    assert delivery.failed?
    assert delivery.error_message.present?
  end

  test "marks the delivery failed when the Notion API call itself fails" do
    delivery = @connection.notion_sync_deliveries.create!(event_type: "page.created", notion_page_id: "notion-page-123")
    original_retrieve_page = NotionClient.instance_method(:retrieve_page)
    NotionClient.define_method(:retrieve_page) { |_page_id| raise NotionClient::Error, "Notion API 401: unauthorized" }

    begin
      NotionSyncJob.perform_now(@connection.id, "notion-page-123", delivery.id)
    ensure
      NotionClient.define_method(:retrieve_page, original_retrieve_page)
    end

    delivery.reload
    assert delivery.failed?
    assert_match "401", delivery.error_message
  end

  test "runs fine without a delivery_id, for backward compatibility with an already-queued job" do
    stub_notion_client(page: notion_page(title: "Test"), blocks: []) do
      assert_nothing_raised do
        NotionSyncJob.perform_now(@connection.id, "notion-page-123")
      end
    end
  end
end
