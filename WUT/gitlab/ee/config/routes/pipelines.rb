# frozen_string_literal: true

resources :pipelines, only: [] do
  member do
    get :security
    get :licenses
    get :license_count
    get :codequality_report
  end
end
