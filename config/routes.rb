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
    collection { get :docs }
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
    end
  end
end
