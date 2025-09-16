# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class Billing < QA::Page::Base
            view 'ee/app/views/shared/billings/_billing_plans_layout.html.haml' do
              element 'billing-plan-header-content'
            end

            def billing_plan_header
              find_element('billing-plan-header-content').text
            end

            def click_start_your_free_trial
              within_element('duo-enterprise-trial-alert') do
                click_link_with_text("Start free trial of GitLab Ultimate and GitLab Duo Enterprise")
              end
            end
          end
        end
      end
    end
  end
end
