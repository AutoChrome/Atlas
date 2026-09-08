require "test_helper"

class WebhookDeliveryJobTest < ActiveJob::TestCase
  setup do
    @announcement = Announcement.create!(
      title: "Scheduled maintenance", starts_on: Date.current, ends_on: Date.current,
      content: "<div><strong>Some content</strong></div>"
    )
  end

  test "sends html format content by default" do
    webhook = Webhook.create!(description: "Default", url: "https://example.com/hook", active: true)

    requests = perform_and_capture_requests(@announcement.id, [ webhook.id ])

    body = JSON.parse(requests.fetch(webhook.id))
    assert_equal "html", body.dig("announcement", "content_format")
    assert_match "<strong>Some content</strong>", body.dig("announcement", "content")
  end

  test "sends plain_text format content when the webhook is configured that way" do
    webhook = Webhook.create!(description: "Plain", url: "https://example.com/hook", active: true, content_format: :plain_text)

    requests = perform_and_capture_requests(@announcement.id, [ webhook.id ])

    body = JSON.parse(requests.fetch(webhook.id))
    assert_equal "plain_text", body.dig("announcement", "content_format")
    assert_equal "Some content", body.dig("announcement", "content")
    refute_match "<strong>", body.dig("announcement", "content")
  end

  test "each webhook gets a body matching its own content_format, and a signature computed over that exact body" do
    html_webhook = Webhook.create!(description: "HTML", url: "https://example.com/hook", active: true, content_format: :html)
    text_webhook = Webhook.create!(description: "Text", url: "https://example.com/hook", active: true, content_format: :plain_text)

    requests = perform_and_capture_requests(@announcement.id, [ html_webhook.id, text_webhook.id ])

    refute_equal requests.fetch(html_webhook.id), requests.fetch(text_webhook.id)
  end

  test "includes a webhook's own custom_parameters in the payload" do
    webhook = Webhook.create!(description: "Default", url: "https://example.com/hook", active: true)
    webhook.update!(custom_parameters_json: '{"team": "platform", "priority": 1}')

    requests = perform_and_capture_requests(@announcement.id, [ webhook.id ])

    body = JSON.parse(requests.fetch(webhook.id))
    assert_equal({ "team" => "platform", "priority" => 1 }, body["custom_parameters"])
  end

  test "custom_parameters is an empty object, not absent, when nothing's configured" do
    webhook = Webhook.create!(description: "Default", url: "https://example.com/hook", active: true)

    requests = perform_and_capture_requests(@announcement.id, [ webhook.id ])

    body = JSON.parse(requests.fetch(webhook.id))
    assert_equal({}, body["custom_parameters"])
  end

  test "each webhook's own custom_parameters go out independently, not shared across webhooks" do
    team_a = Webhook.create!(description: "A", url: "https://example.com/hook", active: true)
    team_a.update!(custom_parameters_json: '{"team": "a"}')
    team_b = Webhook.create!(description: "B", url: "https://example.com/hook", active: true)
    team_b.update!(custom_parameters_json: '{"team": "b"}')

    requests = perform_and_capture_requests(@announcement.id, [ team_a.id, team_b.id ])

    assert_equal "a", JSON.parse(requests.fetch(team_a.id)).dig("custom_parameters", "team")
    assert_equal "b", JSON.parse(requests.fetch(team_b.id)).dig("custom_parameters", "team")
  end

  test "renamed field is content, not the old content_html key" do
    webhook = Webhook.create!(description: "Default", url: "https://example.com/hook", active: true)

    requests = perform_and_capture_requests(@announcement.id, [ webhook.id ])

    body = JSON.parse(requests.fetch(webhook.id))
    assert body["announcement"].key?("content")
    refute body["announcement"].key?("content_html")
  end

  test "records a successful delivery" do
    webhook = Webhook.create!(description: "Default", url: "https://example.com/hook", active: true)

    assert_difference "webhook.webhook_deliveries.count", 1 do
      perform_and_capture_requests(@announcement.id, [ webhook.id ])
    end

    # Scoped to this specific webhook, not .last — fixture rows (see
    # webhook_deliveries.yml) have their own hash-derived ids, which can
    # sort after a freshly-created record's sequential one.
    delivery = webhook.webhook_deliveries.sole
    assert delivery.success?
    assert_equal 200, delivery.status_code
  end

  private
    # Stubs the job's own private #post (rather than pulling in a mocking
    # gem for one HTTP call — same reasoning as SearchStubTestHelper)
    # to capture the exact JSON body sent to each webhook, keyed by
    # webhook id, without making a real HTTP request.
    def perform_and_capture_requests(announcement_id, webhook_ids)
      requests = {}
      # A block passed to define_singleton_method runs with `self` bound to
      # the receiver (job), not this test instance, so a call to another
      # test-instance method from inside it would raise NameError — hence
      # capturing the fake response as a local variable first, which the
      # closure keeps regardless of `self`.
      response = fake_success_response
      job = WebhookDeliveryJob.new
      job.define_singleton_method(:post) do |webhook, body|
        requests[webhook.id] = body
        response
      end
      job.perform(announcement_id, webhook_ids)
      requests
    end

    # A bare Net::HTTPOK has no body attached (it's normally filled in by
    # reading off a real socket) — calling #body on one raises IOError
    # ("attempt to read body out of block"), which #deliver's own body.to_s
    # would trigger and swallow into a false "failed" delivery. Poking the
    # same internal state Net::HTTPResponse#read_body sets is simpler than
    # standing up a real (even fake) socket just to get a readable body.
    def fake_success_response
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, "ok")
      response
    end
end
