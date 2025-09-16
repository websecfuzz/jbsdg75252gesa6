# frozen_string_literal: true

module Gitlab
  module Analytics
    module CycleAnalytics
      module Summary
        class LeadTimeForChanges < BaseDoraSummary
          def title
            s_('CycleAnalytics|Lead time for changes')
          end

          def links
            helpers = Gitlab::Routing.url_helpers

            dashboard_link =
              if @stage.namespace.is_a?(::Group)
                helpers.group_analytics_ci_cd_analytics_path(@stage.namespace, tab: 'lead-time')
              else
                helpers.charts_project_pipelines_path(@stage.namespace.project, chart: 'lead-time')
              end

            [
              { "name" => _('Lead time for changes'),
                "url" => dashboard_link,
                "label" => s_('ValueStreamAnalytics|Dashboard') },
              { "name" => _('Lead time for changes'),
                "url" => helpers.help_page_path('user/analytics/_index.md', anchor: 'definitions'),
                "docs_link" => true,
                "label" => s_('ValueStreamAnalytics|Go to docs') }
            ]
          end

          private

          def metric_key
            'lead_time_for_changes'
          end
        end
      end
    end
  end
end
