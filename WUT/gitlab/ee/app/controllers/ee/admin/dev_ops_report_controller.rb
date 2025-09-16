# frozen_string_literal: true

module EE
  module Admin
    module DevOpsReportController
      extend ActiveSupport::Concern
      prepended do
        track_internal_event :show,
          name: 'i_analytics_dev_ops_adoption',
          category: name,
          conditions: -> { show_adoption? && params[:tab] != 'devops-score' }
      end

      def should_track_devops_score?
        !show_adoption? || params[:tab] == 'devops-score'
      end

      def show_adoption?
        ::License.feature_available?(:devops_adoption)
      end
    end
  end
end
