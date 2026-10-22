Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "lists#new"
  post "/" => "lists#create", as: :lists
  # Posted, so the key is in the body rather than in the address.
  post "find" => "lists#find", as: :find_list

  # The API with the key in a header or a parameter: one address for every list.
  get "list" => "api#show", as: :api_list
  post "claim" => "api#claim"
  post "reserve" => "api#reserve"
  post "release" => "api#release"

  scope ":token", constraints: { token: List::TOKEN } do
    get "/" => "lists#show", as: :list
    patch "/" => "lists#update"

    # The page: humans choosing the names.
    post "names" => "names#create", as: :list_names
    delete "names/:value" => "names#destroy", as: :list_name
    delete "claims/:name" => "claims#destroy", as: :list_claim

    # The API: agents taking them.
    post "claim" => "api#claim"
    post "reserve" => "api#reserve"
    post "release" => "api#release"
  end
end
