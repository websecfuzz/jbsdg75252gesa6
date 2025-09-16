# frozen_string_literal: true

module EE
  module Nav
    module NewDropdownHelper
      extend ::Gitlab::Utils::Override

      private

      override :create_epic_menu_item
      def create_epic_menu_item(group)
        return if ::Feature.enabled?(:work_item_planning_view, group)

        if can?(current_user, :create_epic, group)
          ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'create_epic',
            title: _('New epic'),
            component: 'create_new_work_item_modal',
            data: {
              track_action: 'click_link_new_epic',
              track_label: 'plus_menu_dropdown',
              track_property: 'navigation_top'
            }
          )
        end
      end
    end
  end
end
