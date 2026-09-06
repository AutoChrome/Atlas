require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Atlas
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.active_job.queue_adapter = :sidekiq

    # The `audited` gem YAML-serializes changed attribute values into its
    # `audited_changes` text column. Rails' safe YAML column coder (the
    # 8.1 default) refuses to dump any class not explicitly permitted here —
    # Symbol is allowed out of the box, but auditing a datetime attribute
    # (e.g. Announcement#published_at) also needs Time and its
    # ActiveSupport::TimeWithZone/TimeZone wrapper classes permitted, and a
    # plain date attribute (e.g. Announcement#starts_on/#ends_on) needs Date,
    # or `Audited::Auditor#audited_changes` blows up with
    # Psych::DisallowedClass the first time such an attribute changes.
    config.active_record.yaml_column_permitted_classes = [
      Symbol, Time, Date, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone
    ]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
