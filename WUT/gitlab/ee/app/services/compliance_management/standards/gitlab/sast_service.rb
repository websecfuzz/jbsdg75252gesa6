# frozen_string_literal: true

module ComplianceManagement
  module Standards
    module Gitlab
      class SastService < BaseService
        CHECK_NAME = :sast

        private

        def status
          pipeline = project.latest_successful_pipeline_for_default_branch

          return :fail if pipeline.nil?

          pipeline.job_artifacts.sast.count > 0 ? :success : :fail
        end
      end
    end
  end
end
