# frozen_string_literal: true

module Groups
  module Epics
    class EpicLinksController < Groups::ApplicationController
      include EpicRelations

      before_action :check_epics_available!, only: [:index, :destroy]
      before_action :check_subepics_available!, only: [:create, :update]

      feature_category :portfolio_management
      urgency :default

      def update
        result = ::Epics::EpicLinks::UpdateService.new(child_epic, current_user, params[:epic]).execute

        render json: { message: result[:message] }, status: result[:http_status]
      end

      def destroy
        result = ::Epics::EpicLinks::DestroyService.new(child_epic, current_user).execute

        render json: { issuables: issuables }, status: result[:http_status]
      end

      private

      def authorize_admin!
        ability_name = action_name == 'update' ? :admin_epic_relation : :read_epic_relation

        render_403 unless can?(current_user, ability_name, epic)
      end

      def create_service
        ::WorkItems::LegacyEpics::EpicLinks::CreateService.new(epic, current_user, create_params)
      end

      def list_service
        ::Epics::EpicLinks::ListService.new(epic, current_user)
      end

      def child_epic
        @child_epic ||= Epic.find(params[:id])
      end
    end
  end
end
