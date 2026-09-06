require "sidekiq/web"

Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  root "areas#index"

  get "search", to: "search#index"
  get "icon_suggestions", to: "icon_suggestions#index"

  resources :areas, param: :slug do
    collection { patch :reorder }

    resources :pages, param: :slug do
      member do
        patch :move
      end
    end
  end

  resource :profile, only: %i[edit update]
  resource :guest_preview, only: %i[create destroy]
  resources :api_tokens, only: %i[index create destroy] do
    collection do
      get :docs
      get :openapi
      get :bruno_collection
    end
  end

  resources :announcements do
    member { post :publish }
  end

  resources :projects, param: :slug do
    resources :roadmap_sections, path: "sections", only: %i[create update destroy] do
      collection { patch :reorder }
    end

    resources :roadmap_cards, path: "cards", only: %i[create update destroy] do
      collection { patch :move }
    end
  end

  admin_only = lambda do |request|
    Session.find_by(id: request.cookie_jar.signed[:session_id])&.user&.admin?
  end

  namespace :admin do
    resources :users do
      member do
        post :resend_setup_email
      end
    end
    resources :audits, only: %i[index show]

    resources :webhooks do
      collection { get :docs }
      member { post :regenerate_secret }
    end

    namespace :integrations do
      get "basecamp", to: "basecamp#show"
    end
  end

  # Inbound — Basecamp posts to this when a Message is created, no session
  # or CSRF token involved. :token is the shared secret from
  # BASECAMP_WEBHOOK_TOKEN (see Integrations::BasecampController); Basecamp
  # doesn't sign its webhooks, so the URL itself is what's kept secret.
  namespace :integrations do
    post "basecamp/webhook/:token", to: "basecamp#webhook", as: :basecamp_webhook
  end

  constraints admin_only do
    mount Sidekiq::Web => "/admin/sidekiq"
  end
  # RailsPerformance protects its own mount point via config.verify_access_proc
  # (config/initializers/rails_performance.rb) rather than a route constraint.
  mount RailsPerformance::Engine, at: RailsPerformance.mount_at

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :areas, param: :slug
      resources :pages
      resources :attachments, only: %i[create]
      resources :announcements
      resources :webhooks, only: %i[index show]
      get "search", to: "search#index"
    end
  end
end
