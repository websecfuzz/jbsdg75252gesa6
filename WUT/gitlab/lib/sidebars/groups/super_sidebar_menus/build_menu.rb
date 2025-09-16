# frozen_string_literal: true

module Sidebars
  module Groups
    module SuperSidebarMenus
      class BuildMenu < ::Sidebars::Menu
        override :title
        def title
          s_('Navigation|Build')
        end

        override :sprite_icon
        def sprite_icon
          'rocket'
        end

        override :configure_menu_items
        def configure_menu_items
          [
            :runners
          ].each { |id| add_item(::Sidebars::NilMenuItem.new(item_id: id)) }
        end
      end
    end
  end
end
