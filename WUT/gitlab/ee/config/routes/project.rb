# frozen_string_literal: true

constraints(::Constraints::ProjectUrlConstrainer.new) do
  scope(
    path: '*namespace_id',
    as: :namespace,
    namespace_id: Gitlab::PathRegex.full_namespace_route_regex
  ) do
    scope(
      path: ':project_id',
      constraints: { project_id: Gitlab::PathRegex.project_route_regex },
      module: :projects,
      as: :project
    ) do
      # Begin of the /-/ scope.
      # Use this scope for all new project routes.
      scope '-' do
        draw :google_cloud

        namespace :requirements_management do
          resources :requirements, only: [:index] do
            collection do
              post :import_csv
              post 'import_csv/authorize', to: 'requirements#authorize'
            end
          end
        end

        scope :automate do
          get '/(*vueroute)' => 'duo_agents_platform#show', as: :automate, format: false
          get '/agent-sessions/(*vueroute)' => 'duo_agents_platform#show', as: :automate_agent_sessions, format: false
        end

        namespace :quality do
          resources :test_cases, only: [:index, :new, :show]
        end

        resources :autocomplete_sources, only: [] do
          collection do
            get 'epics'
            get 'iterations'
            get 'vulnerabilities'
          end
        end

        resources :target_branch_rules, only: [:index, :create, :destroy]

        resources :comment_templates, only: [:index, :show], action: :index

        resources :automations, only: [:index]

        resources :subscriptions, only: [:create, :destroy]

        resource :get_started, only: :show, controller: :get_started, param: :project_id do
          get :end_tutorial, on: :member
        end

        resource :learn_gitlab, only: :show, controller: :learn_gitlab, param: :project_id do
          get :end_tutorial, on: :member
        end

        resources :protected_environments, only: [:create, :update, :destroy], constraints: { id: /\d+/ } do
          collection do
            get 'search'
          end
        end

        resources :audit_events, only: [:index]

        namespace :security do
          resources :dashboard, only: [:index], controller: :dashboard
          resources :vulnerability_report, only: [:index], controller: :vulnerability_report
          resource :compliance_dashboard, path: 'compliance_dashboard(/*vueroute)', only: [:show]
          resources :compliance_violations, only: [:show], constraints: { id: /\d+/ }
          resources :policies, only: [:index, :new, :edit], constraints: { id: %r{[^/]+} } do
            collection do
              get :schema
            end
          end

          resource :configuration, only: [], controller: :configuration do
            resource :corpus_management, only: [:show], controller: :corpus_management
            resource :api_fuzzing, only: :show, controller: :api_fuzzing_configuration
            resource :profile_library, only: [:show], controller: :dast_profiles do
              resources :dast_site_profiles, only: [:new, :edit]
              resources :dast_scanner_profiles, only: [:new, :edit]
            end
            resource :dast, only: :show, controller: :dast_configuration
            resource :secret_detection, only: :show, controller: :secret_detection_configuration
          end

          resource :discover, only: [:show], controller: :discover

          resources :scanned_resources, only: [:index]

          resources :vulnerabilities, only: [:show, :new] do
            member do
              get :discussions, format: :json
            end

            scope module: :vulnerabilities do
              resources :notes, only: [:index, :create, :destroy, :update], concerns: :awardable, constraints: { id: /\d+/ }
            end
          end
        end

        namespace :analytics do
          resources :code_reviews, only: [:index]
          resource :issues_analytics, only: [:show]
          resource :merge_request_analytics, only: :show
          resources :dashboards, only: [:index], path: 'dashboards(/*vueroute)', format: false

          scope module: :cycle_analytics, as: 'cycle_analytics', path: 'value_stream_analytics' do
            resources :value_streams
            get '/value_streams/:value_stream_id/stages/:id/average_duration_chart' => 'stages#average_duration_chart', as: 'average_duration_chart'
            get '/time_summary' => 'summary#time_summary'
          end
        end

        resources :approvers, only: :destroy
        resources :approver_groups, only: :destroy
        resources :push_rules, constraints: { id: /\d+/ }, only: [:update]
        resources :vulnerability_feedback, only: [:index, :create, :update, :destroy], constraints: { id: /\d+/ }
        namespace :vulnerability_feedback do
          get :count
        end
        resources :dependencies, only: [:index] do
          collection do
            get :licenses, format: :json
          end
        end

        resources :feature_flags, param: :iid do
          resources :feature_flag_issues, only: [:index, :create, :destroy], as: 'issues', path: 'issues'
        end

        resources :on_demand_scans, only: [:index, :new, :edit]

        namespace :integrations do
          namespace :jira do
            resources :issues, only: [:index, :show]
          end

          namespace :zentao do
            resources :issues, only: [:index, :show]
          end
        end

        resources :iterations, only: [:index, :show], constraints: { id: /\d+/ }

        resources :iteration_cadences, path: 'cadences(/*vueroute)', action: :index do
          resources :iterations, only: [:index, :show], constraints: { id: /\d+/ }, controller: :iteration_cadences, action: :index
        end

        namespace :incident_management, path: '' do
          resources :oncall_schedules, only: [:index], path: 'oncall_schedules'
          resources :escalation_policies, only: [:index], path: 'escalation_policies'
        end

        namespace :settings do
          resource :analytics, only: [:show, :update]
        end

        resources :secrets, path: 'secrets(/*vueroute)', only: [:index]

        resources :tracing, only: [:index, :show], controller: :tracing

        resources :metrics, only: [:index, :show], constraints: { id: %r{[^/]+}, type: /\w+/ }, controller: :metrics

        resources :logs, only: [:index], controller: :logs

        namespace :ml do
          resources :agents, path: 'agents(/*vueroute)', action: :index
        end

        resources :merge_trains, only: [:index]
      end
      # End of the /-/ scope.

      # All new routes should go under /-/ scope.
      # Look for scope '-' at the top of the file.
      # rubocop: disable Cop/PutProjectRoutesUnderScope

      resources :path_locks, only: [:index, :destroy] do
        collection do
          post :toggle
        end
      end

      resource :insights, only: [:show], defaults: { trailing_slash: true } do
        collection do
          post :query
        end
      end
      # All new routes should go under /-/ scope.
      # Look for scope '-' at the top of the file.
      # rubocop: enable Cop/PutProjectRoutesUnderScope
    end
  end
end
