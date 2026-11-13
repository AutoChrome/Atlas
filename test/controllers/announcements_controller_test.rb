require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:one)
    @user.update!(role: :admin)
    @announcement = announcements(:one)
    @webhook = webhooks(:one)
    @announcement.update!(starts_on: Date.current, ends_on: Date.current + 1.month, published_webhook_ids: [ @webhook.id ])
    sign_in_as(@user)
  end

  test "a published announcement shows a Republish button" do
    get announcement_path(@announcement)

    assert_select "form[action=?] input[name='webhook_ids[]'][value=?]", publish_announcement_path(@announcement), @webhook.id.to_s
    assert_select "button", text: "Republish"
  end

  test "a draft announcement has no Republish button" do
    @announcement.update!(published_at: nil)

    get announcement_path(@announcement)

    assert_select "button", text: "Republish", count: 0
  end

  test "republishing re-sends to the platforms it was last sent to" do
    assert_enqueued_with(job: WebhookDeliveryJob, args: [ WebhookDeliveryJob::PUBLISHED, @announcement.id, [ @webhook.id ] ]) do
      post publish_announcement_path(@announcement), params: { webhook_ids: [ @webhook.id ] }
    end

    assert_redirected_to announcement_path(@announcement)
  end
end
