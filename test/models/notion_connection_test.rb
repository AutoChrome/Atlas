require "test_helper"

class NotionConnectionTest < ActiveSupport::TestCase
  test "generates a unique webhook_token on create" do
    connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))

    assert connection.webhook_token.present?
  end

  test "does not overwrite an explicitly set webhook_token" do
    connection = NotionConnection.create!(
      name: "Test", integration_token: "secret_abc", area: areas(:one), webhook_token: "explicit-token"
    )

    assert_equal "explicit-token", connection.webhook_token
  end

  test "requires a unique webhook_token" do
    duplicate = NotionConnection.new(
      name: "Duplicate", integration_token: "secret_abc", area: areas(:one),
      webhook_token: notion_connections(:one).webhook_token
    )

    assert_not duplicate.valid?
  end

  test "requires an integration_token" do
    connection = NotionConnection.new(name: "Test", area: areas(:one))

    assert_not connection.valid?
    assert_includes connection.errors[:integration_token], "can't be blank"
  end

  # Fixture-provided values for `encrypts`-declared columns aren't real
  # ciphertext (the fixture loader writes them verbatim, it doesn't run
  # them through the encryptor), so reading one back raises a decryption
  # error — anything that actually decrypts integration_token/
  # verification_token needs a genuinely created record, not a fixture.
  # webhook_token is NOT encrypted, so fixtures are fine wherever only
  # that's needed (see the controller test).
  test "awaiting_verification? is true until Notion's handshake sets verification_token" do
    connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))
    assert connection.awaiting_verification?

    connection.update!(verification_token: "secret_from_notion")
    assert_not connection.awaiting_verification?
  end

  test "receive_verification_token! stores what Notion sends" do
    connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))

    connection.receive_verification_token!("secret_from_notion")

    assert_equal "secret_from_notion", connection.reload.verification_token
    assert_not connection.awaiting_verification?
  end

  test "valid_signature? is false while awaiting verification, regardless of signature" do
    connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))

    assert_not connection.valid_signature?(body: "{}", signature: "sha256=anything")
  end

  test "valid_signature? matches an HMAC-SHA256 of the body keyed by verification_token" do
    connection = NotionConnection.create!(
      name: "Test", integration_token: "secret_abc", area: areas(:one), verification_token: "the-verification-token"
    )
    body = '{"type":"page.content_updated"}'
    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", body)}"

    assert connection.valid_signature?(body: body, signature: expected)
  end

  test "valid_signature? rejects a signature computed with the wrong key" do
    connection = NotionConnection.create!(
      name: "Test", integration_token: "secret_abc", area: areas(:one), verification_token: "the-verification-token"
    )
    body = '{"type":"page.content_updated"}'
    wrong = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "wrong-key", body)}"

    assert_not connection.valid_signature?(body: body, signature: wrong)
  end

  test "valid_signature? rejects a signature computed over a different body" do
    connection = NotionConnection.create!(
      name: "Test", integration_token: "secret_abc", area: areas(:one), verification_token: "the-verification-token"
    )
    signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "the-verification-token", '{"a":1}')}"

    assert_not connection.valid_signature?(body: '{"a":2}', signature: signature)
  end

  test "regenerate_webhook_token! replaces the URL-path secret" do
    connection = NotionConnection.create!(name: "Test", integration_token: "secret_abc", area: areas(:one))
    original = connection.webhook_token

    connection.regenerate_webhook_token!

    assert_not_equal original, connection.reload.webhook_token
  end
end
