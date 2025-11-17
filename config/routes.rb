Rails.application.routes.draw do
  # Root path
  root "home#index"

  # Authentication routes
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  get "magic_link/:token", to: "sessions#magic_link", as: :magic_link
  delete "logout", to: "sessions#destroy", as: :logout

  # Test-only routes (only available in development/test)
  if Rails.env.development? || Rails.env.test?
    get "test_login", to: "test_sessions#create"
  end

  # Public pages
  get "about", to: "pages#about"
  get "contact", to: "pages#contact"
  get "pricing", to: "pages#pricing"
  get "terms", to: "pages#terms"
  get "privacy", to: "pages#privacy"

  # Services (public viewing)
  resources :services, only: [:index, :show] do
    member do
      get :availability
      get :calendar
    end
  end

  # User area
  resources :bookings do
    collection do
      post :select_time
      get :review
      get :confirm
      post :create_guest_booking
    end

    member do
      post :cancel
      post :reschedule
      get :receipt
      get :check_payment_status
    end

    resource :payment, only: [:show] do
      member do
        post :process_payment
        post :refund
      end
    end
  end

  # Booking review and confirmation
  get "bookings/review", to: "bookings#review", as: :review_booking
  get "bookings/confirm", to: "bookings#confirm", as: :confirm_booking

  # Calendar view
  get "calendar", to: "bookings#calendar", as: :calendar

  # User profile
  resource :profile, only: [:show, :edit, :update] do
    member do
      get :bookings
      get :payments
      patch :update_preferences
    end
  end

  # Stripe webhooks
  post "webhooks/stripe", to: "payments#webhook"

  # Admin area
  namespace :admin do
    root "dashboard#index", as: :dashboard

    resources :users do
      member do
        post :make_admin
        post :revoke_admin
        post :impersonate
      end
    end

    resources :services do
      resources :availability_schedules
      resources :blocked_dates
      member do
        post :toggle_active
        patch :update_position
      end
    end

    resources :bookings do
      member do
        post :confirm
        post :cancel
        post :mark_complete
        post :mark_no_show
      end
      collection do
        get :calendar
        get :export
      end
    end

    resources :payments do
      member do
        post :refund
      end
      collection do
        get :export
      end
    end

    resources :audit_logs, only: [:index, :show]

    # Reports
    namespace :reports do
      get :revenue
      get :bookings
      get :services
      get :users
      get :occupancy
    end

    # Settings
    resource :settings, only: [:show, :update] do
      member do
        get :email
        get :payment
        get :general
        patch :update_email
        patch :update_payment
        patch :update_general
      end
    end
  end

  # API endpoints (for future mobile app or integrations)
  namespace :api do
    namespace :v1 do
      resources :services, only: [:index, :show] do
        member do
          get :availability
        end
      end

      resources :bookings, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end

      resources :users, only: [:show] do
        member do
          get :bookings
        end
      end
    end
  end

  # Health check
  get "health", to: "health#index"

  # Sidekiq Web UI (admin only)
  require "sidekiq/web"
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Letter Opener Web (development only)
  # if Rails.env.development? && defined?(LetterOpenerWeb)
  #   mount LetterOpenerWeb::Engine, at: "/letter_opener"
  # end

  # Catch all route for 404s
  match "*path", to: "errors#not_found", via: :all
end