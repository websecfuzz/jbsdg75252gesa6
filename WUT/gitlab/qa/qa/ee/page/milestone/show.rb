# frozen_string_literal: true

module QA
  module EE
    module Page
      module Milestone
        module Show
          extend QA::Page::PageConcern

          def self.prepended(base)
            super
            base.class_eval do
              view 'ee/app/assets/javascripts/burndown_chart/components/burn_charts.vue' do
                element 'weight-button'
              end

              view 'ee/app/assets/javascripts/burndown_chart/components/burndown_chart.vue' do
                element 'burndown-chart'
              end

              view 'ee/app/views/shared/milestones/_weight.html.haml' do
                element 'total-issue-weight-value'
              end
            end
          end

          def burndown_chart
            find_element('burndown-chart')
          end

          def click_weight_button
            click_element('weight-button')
          end

          def total_issue_weight_value
            find_element('total-issue-weight-value')
          end
        end
      end
    end
  end
end
