# frozen_string_literal: true

resources :virtual_registries, only: [:index]
namespace :virtual_registries do
  namespace :maven do
    resources :registries, path: '', only: [:new, :index, :create, :show, :edit, :update, :destroy] do
      resources :upstreams, only: [:show, :edit], shallow: true
    end
  end
end
