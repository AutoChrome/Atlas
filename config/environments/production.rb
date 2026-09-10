require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files locally, or on S3 if STORAGE_SERVICE=amazon (see config/storage.yml).
  config.active_storage.service = ENV.fetch("STORAGE_SERVICE", "local").to_sym

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates. Without an
  # explicit :protocol here, Action Mailer defaults to "http" — Caddy does
  # redirect that to https, but a password-reset link (a sensitive token in
  # the URL) shouldn't transit even that first unencrypted request.
  config.action_mailer.default_url_options = { host: ENV.fetch("SITE_ADDRESS", "example.com"), protocol: "https" }

  # Outgoing mail via SMTP (e.g. AWS SES's SMTP interface) — plain env vars
  # like everything else in this app's config (see .env.example), not Rails
  # encrypted credentials. Left unconfigured (Action Mailer's own default)
  # if SMTP_ADDRESS isn't set, so a deploy without email set up yet still
  # boots — only sending mail fails, not the whole app.
  if ENV["SMTP_ADDRESS"].present?
    # SMTP_USE_SSL is for implicit TLS on connect (typically port 465) —
    # mutually exclusive with STARTTLS (the plain-then-upgrade handshake on
    # port 587, the default below).
    smtp_use_ssl = ActiveModel::Type::Boolean.new.cast(ENV["SMTP_USE_SSL"])

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      domain: ENV["SMTP_DOMAIN"].presence,
      user_name: ENV.fetch("SMTP_USERNAME"),
      password: ENV.fetch("SMTP_PASSWORD"),
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "login").to_sym,
      enable_starttls_auto: !smtp_use_ssl,
      ssl: smtp_use_ssl
    }.compact
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts << ENV["SITE_ADDRESS"] if ENV["SITE_ADDRESS"].present?
  #
  # Skip DNS rebinding protection for the default health check endpoint —
  # needed so scripts/deploy.sh's blue/green health check can curl a fresh
  # container by its bare "localhost:3000" from inside itself, without a
  # Host header matching SITE_ADDRESS (which it has no way to send there).
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
