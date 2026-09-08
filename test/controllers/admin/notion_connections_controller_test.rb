require "test_helper"

module Admin
  class NotionConnectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update!(role: :admin)
      @area = areas(:one)
    end

    test "a non-admin cannot reach the index" do
      users(:two).update!(role: :member)
      sign_in_as(users(:two))

      get admin_notion_connections_path

      assert_redirected_to root_path
    end

    test "an admin can create a connection" do
      sign_in_as(@admin)

      assert_difference "NotionConnection.count", 1 do
        post admin_notion_connections_path, params: {
          notion_connection: { name: "Design Notion", integration_token: "secret_abc", area_id: @area.id }
        }
      end

      connection = NotionConnection.last
      assert_redirected_to admin_notion_connection_path(connection)
      assert_equal "Design Notion", connection.name
      assert connection.webhook_token.present?
    end

    test "create fails without an integration_token" do
      sign_in_as(@admin)

      assert_no_difference "NotionConnection.count" do
        post admin_notion_connections_path, params: { notion_connection: { name: "No token", area_id: @area.id } }
      end

      assert_response :unprocessable_entity
    end

    test "show exposes the webhook URL" do
      sign_in_as(@admin)
      connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)

      get admin_notion_connection_path(connection)

      assert_response :success
      assert_match connection.webhook_token, response.body
    end

    test "updating with a blank integration_token keeps the existing one" do
      sign_in_as(@admin)
      connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)

      patch admin_notion_connection_path(connection), params: {
        notion_connection: { name: "Renamed", integration_token: "" }
      }

      connection.reload
      assert_equal "Renamed", connection.name
      assert_equal "secret_abc", connection.integration_token
    end

    test "updating with a new integration_token replaces it" do
      sign_in_as(@admin)
      connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)

      patch admin_notion_connection_path(connection), params: {
        notion_connection: { integration_token: "secret_xyz" }
      }

      assert_equal "secret_xyz", connection.reload.integration_token
    end

    test "regenerate_webhook_token issues a new URL token without touching verification_token" do
      sign_in_as(@admin)
      connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)
      connection.receive_verification_token!("the-verification-token")
      original_webhook_token = connection.webhook_token

      post regenerate_webhook_token_admin_notion_connection_path(connection)

      connection.reload
      assert_not_equal original_webhook_token, connection.webhook_token
      assert_equal "the-verification-token", connection.verification_token
    end

    test "destroy removes the connection" do
      sign_in_as(@admin)
      connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: @area)

      assert_difference "NotionConnection.count", -1 do
        delete admin_notion_connection_path(connection)
      end
    end
  end
end
