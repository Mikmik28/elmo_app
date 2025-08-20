Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'
  
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA routes
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Main application routes
  resources :loans do
    member do
      patch :approve
      patch :disburse
    end
    
    resources :payments, except: [:edit, :update, :destroy] do
      member do
        patch :cancel
      end
    end
  end

  # Webhook routes
  post '/webhooks/payments/:payment_reference', to: 'payments#webhook', as: :payment_webhook

  # API routes
  namespace :api do
    namespace :v1 do
      resources :loans, only: [:index, :show, :create] do
        collection do
          post :calculate
        end
      end
      
      resources :payments, only: [:create]
    end
  end

  # Sidekiq web interface (admin only)
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
