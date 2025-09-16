# frozen_string_literal: true

module QA
  module EE
    module Page
      module Main
        module Menu
          def go_to_operations
            click_element('nav-item-link', submenu_item: 'Operations')
          end
        end
      end
    end
  end
end
