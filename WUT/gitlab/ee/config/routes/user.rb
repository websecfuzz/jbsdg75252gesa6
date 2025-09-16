# frozen_string_literal: true

devise_scope :user do
  get '/users/auth/kerberos/negotiate' => 'omniauth_kerberos#negotiate'
  post '/users/password/complexity' => 'passwords#complexity'
end

scope '-/users', module: :users do
  resources :targeted_message_dismissals, only: [:create]
end

scope(constraints: { username: Gitlab::PathRegex.root_namespace_route_regex }) do
  scope(path: 'users/:username', as: :user, controller: :users) do
    get :available_project_templates
    get :available_group_templates
  end
end
