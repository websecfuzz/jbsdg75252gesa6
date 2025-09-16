# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module WorkItem
          module Index
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/issues/list/components/issue_card_time_info.vue' do
                  element 'issuable-weight-content'
                end
              end
            end

            def issuable_weight
              find_element('issuable-weight-content')
            end
          end
        end
      end
    end
  end
end
