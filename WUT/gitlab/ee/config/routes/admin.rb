# frozen_string_literal: true

namespace :admin do
  resources :users, only: [], constraints: { id: %r{[a-zA-Z./0-9_\-]+} } do
    member do
      post :identity_verification_exemption
      delete :destroy_identity_verification_exemption
      post :reset_runners_minutes
      get :card_match
      get :phone_match
    end
  end

  scope(
    path: 'groups/*id',
    controller: :groups,
    constraints: { id: Gitlab::PathRegex.full_namespace_route_regex, format: /(html|json|atom)/ }
  ) do
    scope(as: :group) do
      post :reset_runners_minutes
    end
  end

  resource :push_rule, only: [:show, :update]
  resource :email, only: [:show, :create]
  resources :audit_logs, controller: 'audit_logs', only: [:index]
  resources :audit_log_reports, only: [:index], constraints: { format: :csv }
  resources :credentials, only: [:index, :destroy] do
    resources :resources, only: [] do
      put :revoke, controller: :credentials
    end
    member do
      put :revoke
    end
  end
  resources :user_permission_exports, controller: 'user_permission_exports', only: [:index]

  resource :license, only: [:show, :create, :destroy] do
    get :download, on: :member
    post :sync_seat_link, on: :collection

    resource :usage_export, controller: 'licenses/usage_exports', only: [:show]
  end

  resource :subscription, only: [:show]
  resources :role_promotion_requests, only: :index

  resource :gitlab_duo, only: [:show], controller: 'gitlab_duo'
  namespace :gitlab_duo do
    resources :seat_utilization, only: [:index]
    resources :configuration, only: [:index]
  end
  get '/code_suggestions', to: redirect('admin/gitlab_duo/seat_utilization')

  namespace :ai do
    get 'duo_self_hosted(/*vueroute)', to: 'duo_self_hosted#index', as: :duo_self_hosted
    post 'duo_self_hosted/toggle_beta_models', to: 'terms_and_conditions#toggle_beta_models'

    resources :duo_workflow_settings, only: [:create] do
      collection do
        post :disconnect
      end
    end

    resources :amazon_q_settings, only: [:index, :create] do
      collection do
        post :disconnect
      end
    end
  end

  # using `only: []` to keep duplicate routes from being created
  resource :application_settings, only: [] do
    get :seat_link_payload
    match :templates, :search, :security_and_compliance, :namespace_storage, :analytics, via: [:get, :patch]
    get :advanced_search, to: redirect('admin/application_settings/search')
    get :geo, to: "geo/settings#show"
    put :update_microsoft_application

    resource :scim_oauth, only: [:create], controller: :scim_oauth, module: 'application_settings'

    resources :roles_and_permissions, only: [:index, :new, :edit, :show], module: 'application_settings'
    resources :service_accounts, path: 'service_accounts(/*vueroute)', only: [:index], module: 'application_settings'
  end

  namespace :geo do
    get '/' => 'nodes#index'

    resources :nodes, path: 'sites', only: [:index, :create, :new, :edit, :update] do
      member do
        scope '/replication' do
          get '/', to: 'nodes#index'
          get '/:replicable_name_plural', to: 'replicables#index', as: 'site_replicables'
          get '/:replicable_name_plural/:replicable_id', to: 'replicables#show', as: 'replicable_details'
        end
      end
    end

    scope '/replication' do
      get '/', to: redirect(path: 'admin/geo/sites')
      get '/:replicable_name_plural', to: 'replicables#index', as: 'replicables'
    end

    resource :settings, only: [:show, :update]
  end

  namespace :elasticsearch do
    post :enqueue_index
    post :trigger_reindexing
    post :cancel_index_deletion
    post :retry_migration
  end

  get 'namespace_limits', to: 'namespace_limits#index'
  get 'namespace_limits/export_usage', to: 'namespace_limits#export_usage'

  resources :runners, only: [] do
    collection do
      get :dashboard
    end
  end

  resources :targeted_messages, only: [:index, :new, :create, :edit, :update]
end
