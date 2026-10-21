Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "lists#new"
  post "/" => "lists#create", as: :lists

  scope ":token", constraints: { token: List::TOKEN } do
    get "/" => "lists#show", as: :list
    patch "/" => "lists#update"

    # The page: humans choosing the names.
    post "names" => "names#create", as: :list_names
    post "names/defaults" => "names#defaults", as: :list_default_names
    delete "names/:value" => "names#destroy", as: :list_name
    delete "claims/:name" => "claims#destroy", as: :list_claim

    # The API: agents taking them.
    post "claim" => "api#claim"
    post "reserve" => "api#reserve"
    post "release" => "api#release"
  end
end
