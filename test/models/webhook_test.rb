require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  test "defaults to html content_format" do
    webhook = Webhook.create!(description: "Test", url: "https://example.com/hook")

    assert webhook.html?
  end

  test "accepts plain_text as an alternate content_format" do
    webhook = Webhook.create!(description: "Test", url: "https://example.com/hook", content_format: :plain_text)

    assert webhook.plain_text?
  end

  test "defaults custom_parameters to an empty object" do
    webhook = Webhook.create!(description: "Test", url: "https://example.com/hook")

    assert_equal({}, webhook.custom_parameters)
    assert_equal "", webhook.custom_parameters_json
  end

  test "custom_parameters_json= parses a JSON object into custom_parameters" do
    webhook = Webhook.new(description: "Test", url: "https://example.com/hook")

    webhook.custom_parameters_json = '{"team": "platform", "priority": 1, "urgent": true, "owner": null}'

    assert_equal(
      { "team" => "platform", "priority" => 1, "urgent" => true, "owner" => nil },
      webhook.custom_parameters
    )
    assert webhook.valid?
  end

  test "custom_parameters_json= treats a blank value as no custom parameters" do
    webhook = Webhook.new(description: "Test", url: "https://example.com/hook")

    webhook.custom_parameters_json = ""

    assert_equal({}, webhook.custom_parameters)
  end

  test "is invalid when custom_parameters_json isn't valid JSON, and preserves the typed text for redisplay" do
    webhook = Webhook.new(description: "Test", url: "https://example.com/hook")

    webhook.custom_parameters_json = "{not json"

    assert_not webhook.valid?
    assert_includes webhook.errors[:custom_parameters], "must be valid JSON"
    assert_equal "{not json", webhook.custom_parameters_json
  end

  test "is invalid when custom_parameters isn't a JSON object" do
    webhook = Webhook.new(description: "Test", url: "https://example.com/hook")

    webhook.custom_parameters_json = "[1, 2, 3]"

    assert_not webhook.valid?
    assert_includes webhook.errors[:custom_parameters], "must be a JSON object, e.g. {\"team\": \"platform\"}"
  end

  test "is invalid when a custom_parameters value is a nested object or array" do
    webhook = Webhook.new(description: "Test", url: "https://example.com/hook")

    webhook.custom_parameters_json = '{"nested": {"a": 1}}'

    assert_not webhook.valid?
    assert_equal [ "value for \"nested\" must be a string, number, boolean, or null — nested objects and arrays aren't supported" ],
      webhook.errors[:custom_parameters]
  end
end
