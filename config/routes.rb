Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :call_records, only: :index
  resources :imports, only: :create

  root "call_records#index"
end
