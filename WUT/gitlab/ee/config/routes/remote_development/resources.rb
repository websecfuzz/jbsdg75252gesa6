# frozen_string_literal: true

namespace :remote_development do
  resources :workspaces, only: [:index], controller: :workspaces, path: "workspaces(/*vueroute)"
end
