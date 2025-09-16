# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Overview
          module Groups
            class Show < QA::Page::Base
              view 'ee/app/views/admin/_namespace_plan_info.html.haml' do
                element 'group-plan-content'
              end

              def group_plan
                find_element('group-plan-content').text
              end
            end
          end
        end
      end
    end
  end
end
