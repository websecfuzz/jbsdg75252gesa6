# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module Create
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          argument :weight_widget,
            ::Types::WorkItems::Widgets::WeightInputType,
            required: false,
            description: 'Input for weight widget.'

          argument :health_status_widget,
            ::Types::WorkItems::Widgets::HealthStatusInputType,
            required: false,
            description: 'Input for health status widget.'

          argument :iteration_widget,
            ::Types::WorkItems::Widgets::IterationInputType,
            required: false,
            description: 'Iteration widget of the work item.'

          argument :color_widget, ::Types::WorkItems::Widgets::ColorInputType,
            required: false,
            description: 'Input for color widget.'

          argument :custom_fields_widget, [::Types::WorkItems::Widgets::CustomFieldValueInputType],
            required: false,
            description: 'Input for custom fields widget.',
            experiment: { milestone: '17.10' }

          argument :vulnerability_id, ::Types::GlobalIDType[::Vulnerability],
            loads: ::Types::VulnerabilityType,
            required: false,
            description: 'Input for linking an existing vulnerability to created work item.',
            experiment: { milestone: '17.9' }

          argument :status_widget, ::Types::WorkItems::Widgets::StatusInputType,
            required: false,
            description: 'Input for status widget.',
            experiment: { milestone: '17.11' }
        end

        override :raise_feature_not_available_error!
        def raise_feature_not_available_error!(type)
          return super unless type.epic?

          raise ::Gitlab::Graphql::Errors::ArgumentError, 'Epic type is not available for the given group'
        end

        override :resolve
        def resolve(project_path: nil, namespace_path: nil, vulnerability: nil, **attributes)
          result = super(project_path: project_path, namespace_path: namespace_path, **attributes)
          work_item = result[:work_item]
          errors = result[:errors]

          return result if errors.any? || vulnerability.blank?

          result = VulnerabilityIssueLinks::CreateService.new(
            current_user, vulnerability, work_item, link_type: Vulnerabilities::IssueLink.link_types[:created]
          ).execute

          {
            work_item: work_item,
            errors: result.errors
          }
        end

        override :check_feature_available!
        def check_feature_available!(container, type, params)
          return super unless container.is_a?(Project) && type.epic?

          raise_resource_not_available_error! unless current_user.can?(:create_epic, container)
        end
      end
    end
  end
end
