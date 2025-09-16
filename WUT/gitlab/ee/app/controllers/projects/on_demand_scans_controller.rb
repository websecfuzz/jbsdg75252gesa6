# frozen_string_literal: true

module Projects
  class OnDemandScansController < Projects::ApplicationController
    include SecurityAndCompliancePermissions
    include API::Helpers::GraphqlHelpers

    before_action :check_on_demand_dast_available
    before_action :authorize_read_on_demand_dast_scan!, only: :index
    before_action :authorize_create_on_demand_dast_scan!, only: [:new]
    before_action :authorize_edit_on_demand_dast_scan!, only: [:edit]
    before_action do
      push_frontend_feature_flag(:dast_pre_scan_verification, @project)
    end

    feature_category :dynamic_application_security_testing
    urgency :low

    def index; end

    def new; end

    def edit
      global_id = Gitlab::GlobalId.as_global_id(params[:id], model_name: 'Dast::Profile')

      dast_profile = Dast::Profile.find(params[:id])
      return render_404 unless dast_profile.can_edit_scan?(current_user)

      query = %(
          {
            project(fullPath: "#{project.full_path}") {
              dastProfile(id: "#{global_id}") {
                id
                name
                description
                tagList
                branch { name }
                dastSiteProfile { id }
                dastScannerProfile { id }
                dastProfileSchedule {
                  active
                  cadence {
                    duration
                    unit
                  }
                  startsAt
                  timezone
                }
              }
            }
          }
        )

      @dast_profile = run_graphql!(
        query: query,
        context: { current_user: current_user },
        transform: ->(result) { result.dig('data', 'project', 'dastProfile') }
      )

      return render_404 unless @dast_profile
    end

    private

    def check_on_demand_dast_available
      render_404 unless project.on_demand_dast_available?
    end
  end
end
