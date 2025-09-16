# frozen_string_literal: true

resource :dashboard, controller: 'dashboard', only: [] do
  scope module: :dashboard do
    resources :projects, only: [:index] do
      collection do
        get :removed, to: redirect('dashboard/projects/inactive')
      end
    end
  end
end
