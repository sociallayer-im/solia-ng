Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  namespace :api, path: "" do
    post "service/send_email", to: "service#send_email"
    post "service/upload_image", to: "service#upload_image"

    get  "profile/me", to: "profile#me"
    post "profile/create", to: "profile#create"
    post "profile/update", to: "profile#update"
    get  "profile/get_by_email", to: "profile#get_by_email"
    post "profile/signin_with_email", to: "profile#signin_with_email"
    post "profile/set_verified_email", to: "profile#set_verified_email"

    post "event/create", to: "event#create"
    post "event/update", to: "event#update"
    post "event/unpublish", to: "event#unpublish"
    post "event/join", to: "event#join"
    post "event/check", to: "event#check"
    post "event/cancel", to: "event#cancel"

  end

  # Defines the root path route ("/")
  root "home#index"
end
