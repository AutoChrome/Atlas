# Allow other applications to call the JSON API (config/routes.rb `/api/*`)
# cross-origin. The API is authenticated with bearer tokens, not cookies, so
# an open origin policy here doesn't expose session-based endpoints.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("API_CORS_ORIGINS", "*").split(",")

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: false
  end
end
