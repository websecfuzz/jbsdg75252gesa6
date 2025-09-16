# frozen_string_literal: true

resources :merge_requests, only: [], constraints: { id: /\d+/ } do
  member do
    get '/descriptions/:version_id/diff', action: :description_diff, as: :description_diff
    delete '/descriptions/:version_id', action: :delete_description_version, as: :delete_description_version
    get :metrics_reports
    get :license_scanning_reports
    get :license_scanning_reports_collapsed
    get :container_scanning_reports
    get :dependency_scanning_reports
    get :sast_reports
    get :secret_detection_reports
    get :dast_reports
    get :coverage_fuzzing_reports
    get :api_fuzzing_reports
    get :security_reports

    # We intentionally need get here since this is invoked via a callback from the SAML Identity Provider(OmniAuth)
    get :saml_approval, action: :create, controller: 'merge_requests/saml_approvals'

    post :rebase

    scope action: :show do
      get :reports, to: 'merge_requests#reports', defaults: { tab: 'reports' }
      get '/reports(/*vueroute)', to: 'merge_requests#reports', defaults: { tab: 'reports' }
    end
  end

  resources :approvers, only: :destroy
  delete 'approvers', to: 'approvers#destroy_via_user_id', as: :approver_via_user_id
  resources :approver_groups, only: :destroy
end
