if defined?(RailsPerformance)
  RailsPerformance.setup do |config|
    config.redis = Redis.new(url: ENV["REDIS_URL"].presence || "redis://redis:6379/0")

    config.duration = 4.hours
    config.recent_requests_time_window = 60.minutes
    config.slow_requests_time_window = 4.hours
    config.slow_requests_threshold = 500 # ms

    config.enabled = true
    config.mount_at = "/admin/performance"

    # The engine's controller is a plain ActionController::Base (not ours),
    # so it can't see our `current_user` helper — re-derive it the same way
    # Authentication#resume_session does, from the signed session cookie.
    config.verify_access_proc = proc do |controller|
      Session.find_by(id: controller.request.cookie_jar.signed[:session_id])&.user&.admin?
    end

    config.ignored_paths = ["/admin/performance"]
    config.home_link = "/"
    config.include_rake_tasks = false
    config.include_custom_events = true
  end
end
