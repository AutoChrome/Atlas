require "test_helper"

module Integrations
  class NotionControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))
    end

    test "an unknown webhook_token is rejected" do
      post integrations_notion_webhook_path(token: "not-a-real-token"), as: :json, params: { type: "page.created" }

      assert_response :unauthorized
    end

    test "a disabled connection's webhook_token is rejected" do
      @connection.update!(active: false)

      post integrations_notion_webhook_path(token: @connection.webhook_token), as: :json, params: { type: "page.created" }

      assert_response :unauthorized
    end

    test "the verification handshake stores verification_token and does not require a signature" do
      assert @connection.awaiting_verification?

      post integrations_notion_webhook_path(token: @connection.webhook_token), as: :json,
        params: { verification_token: "secret_from_notion" }

      assert_response :success
      assert_equal "secret_from_notion", @connection.reload.verification_token
    end

    test "a real event without a valid signature is rejected, even with the right webhook_token" do
      @connection.receive_verification_token!("the-verification-token")

      post integrations_notion_webhook_path(token: @connection.webhook_token), as: :json,
        params: { type: "page.content_updated", entity: { id: "page-1", type: "page" } }

      assert_response :unauthorized
    end

    test "a correctly signed page.content_updated event enqueues NotionSyncJob linked to a new delivery log entry" do
      @connection.receive_verification_token!("the-verification-token")
      body = { type: "page.content_updated", entity: { id: "notion-page-1", type: "page" } }.to_json
      signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", body)}"

      assert_difference "@connection.notion_sync_deliveries.count", 1 do
        assert_enqueued_jobs 1, only: NotionSyncJob do
          post integrations_notion_webhook_path(token: @connection.webhook_token),
            headers: { "X-Notion-Signature" => signature, "Content-Type" => "application/json" }, params: body
        end
      end
      assert_response :success

      delivery = @connection.notion_sync_deliveries.sole
      assert_equal "page.content_updated", delivery.event_type
      assert_equal "notion-page-1", delivery.notion_page_id
      assert delivery.received?
      assert_enqueued_with(job: NotionSyncJob, args: [ @connection.id, "notion-page-1", delivery.id ])
    end

    test "page.created and page.properties_updated also enqueue a sync, matching page.content_updated" do
      @connection.receive_verification_token!("the-verification-token")

      %w[page.created page.properties_updated].each do |event_type|
        body = { type: event_type, entity: { id: "notion-page-1", type: "page" } }.to_json
        signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", body)}"

        assert_enqueued_jobs 1, only: NotionSyncJob do
          post integrations_notion_webhook_path(token: @connection.webhook_token),
            headers: { "X-Notion-Signature" => signature, "Content-Type" => "application/json" }, params: body
        end
      end
    end

    test "an unhandled event type still returns success and is logged, but enqueues nothing" do
      @connection.receive_verification_token!("the-verification-token")
      body = { type: "comment.created", entity: { id: "notion-page-1", type: "page" } }.to_json
      signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", body)}"

      assert_no_enqueued_jobs(only: NotionSyncJob) do
        post integrations_notion_webhook_path(token: @connection.webhook_token),
          headers: { "X-Notion-Signature" => signature, "Content-Type" => "application/json" }, params: body
      end

      assert_response :success
      delivery = @connection.notion_sync_deliveries.sole
      assert_equal "comment.created", delivery.event_type
      assert delivery.ignored?
    end

    test "a page.content_updated event for a non-page entity (e.g. a database) enqueues nothing, and is logged as ignored" do
      @connection.receive_verification_token!("the-verification-token")
      body = { type: "page.content_updated", entity: { id: "db-1", type: "database" } }.to_json
      signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", body)}"

      assert_no_enqueued_jobs(only: NotionSyncJob) do
        post integrations_notion_webhook_path(token: @connection.webhook_token),
          headers: { "X-Notion-Signature" => signature, "Content-Type" => "application/json" }, params: body
      end

      assert_response :success
      assert @connection.notion_sync_deliveries.sole.ignored?
    end

    test "the verification handshake is logged as a succeeded delivery" do
      post integrations_notion_webhook_path(token: @connection.webhook_token), as: :json,
        params: { verification_token: "secret_from_notion" }

      delivery = @connection.notion_sync_deliveries.sole
      assert_equal "verification", delivery.event_type
      assert delivery.succeeded?
    end

    test "an invalid signature is logged as a failed delivery, not silently dropped" do
      @connection.receive_verification_token!("the-verification-token")

      post integrations_notion_webhook_path(token: @connection.webhook_token), as: :json,
        params: { type: "page.content_updated", entity: { id: "page-1", type: "page" } }

      delivery = @connection.notion_sync_deliveries.sole
      assert_equal "page.content_updated", delivery.event_type
      assert delivery.failed?
      assert delivery.error_message.present?
    end

    test "an unknown webhook_token creates no delivery log entry for anyone" do
      assert_no_difference "NotionSyncDelivery.count" do
        post integrations_notion_webhook_path(token: "not-a-real-token"), as: :json, params: { type: "page.created" }
      end
    end
  end
end
