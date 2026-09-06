# Lets models use `encrypts :some_attribute` (currently just Webhook#secret
# — see app/models/webhook.rb). Configured via env vars rather than Rails
# credentials, matching everything else in this app (DATABASE_*, REDIS_URL,
# OPENSEARCH_URL, AWS_*). Generate values with `bin/rails db:encryption:init`.
Rails.application.configure do
  config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
  config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
  config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
end
