require "sidekiq/web"

Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  root "areas#index"

  get "search", to: "search#index"
  get "icon_suggestions", to: "icon_suggestions#index"
  resources :content_tables, only: %i[create edit update]
  resources :callouts, only: %i[create edit update]

  resources :areas, param: :slug do
    resources :pages, param: :slug do
      member do
        patch :move
      end
    end

    resources :charts, param: :slug do
      collection { get :new_import; post :import }
      member { post :preview_import; post :apply_import; get :elsewhere }

      resources :chart_tables, path: "tables", only: %i[create update destroy]
      resources :chart_columns, path: "columns", only: %i[new create edit update destroy]
      resources :chart_relationships, path: "relationships", only: %i[create update destroy]
      resources :chart_indices, path: "indexes", only: %i[new create update destroy]
    end

    resources :tutorials, param: :slug do
      resources :tutorial_steps, path: "steps", only: %i[new create edit update destroy] do
        collection { patch :reorder }
      end

      # Keyed by tutorial_task_id (query param), not a response's own id —
      # the viewer only ever knows "did I tick or cross this task," not any
      # particular response row's id. `accepted` (also a query param, on
      # create) carries which one.
      post "task_responses", to: "tutorial_task_responses#create"
      delete "task_responses", to: "tutorial_task_responses#destroy"

      # "Start over" — clears every one of the current user's responses
      # across the whole tutorial in one request, distinct from destroy's
      # single-task undo above.
      delete "progress", to: "tutorial_task_responses#reset_all"
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

    resources :notion_connections do
      member { post :regenerate_webhook_token }
    end

    namespace :integrations do
      get "basecamp", to: "basecamp#show"
    end
  end

  # Inbound — Basecamp posts to this when a Message is created, no session
  # or CSRF token involved. :token is the shared secret from
  # BASECAMP_WEBHOOK_TOKEN (see Integrations::BasecampController); Basecamp
  # doesn't sign its webhooks, so the URL itself is what's kept secret.
  #
  # Notion posts to the second one when a page shared with a
  # NotionConnection's integration changes — see Integrations::NotionController
  # for its own two-stage verification story.
  namespace :integrations do
    post "basecamp/webhook/:token", to: "basecamp#webhook", as: :basecamp_webhook
    post "notion/webhook/:token", to: "notion#webhook", as: :notion_webhook
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
