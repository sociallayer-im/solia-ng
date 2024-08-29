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

    post "group/create", to: "group#create"
    post "group/update", to: "group#update"
    post "group/freeze", to: "group#freeze_group"
    post "group/transfer_owner", to: "group#transfer_owner"
    post "group/freeze_group", to: "group#freeze_group"
    get  "group/is_manager", to: "group#is_manager"
    get  "group/is_operator", to: "group#is_operator"
    get  "group/is_member", to: "group#is_member"
    post "group/remove_member", to: "group#remove_member"
    post "group/remove_operator", to: "group#remove_operator"
    post "group/remove_manager", to: "group#remove_manager"
    post "group/add_manager", to: "group#add_manager"
    post "group/add_operator", to: "group#add_operator"
    post "group/leave", to: "group#leave"

    post "event/create", to: "event#create"
    post "event/update", to: "event#update"
    post "event/unpublish", to: "event#unpublish"
    post "event/check_group_permission", to: "event#check_group_permission"
    post "event/join", to: "event#join"
    post "event/check", to: "event#check"
    post "event/cancel", to: "event#cancel"

    post "ticket/rsvp", to: "ticket#rsvp"
    post "ticket/set_payment_status", to: "ticket#set_payment_status"
    post "ticket/stripe_callback", to: "ticket#stripe_callback"
    post "ticket/stripe_client_secret", to: "ticket#stripe_client_secret"

  end

  # Defines the root path route ("/")
  root "home#index"
end
