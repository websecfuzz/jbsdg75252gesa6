# frozen_string_literal: true

module Groups
  module Security
    class InventoryController < Groups::ApplicationController
      layout 'group'

      before_action :authorize_read_security_inventory!

      before_action do
        push_frontend_feature_flag(:security_inventory_dashboard, @group.root_ancestor)
      end

      feature_category :security_asset_inventories

      include ProductAnalyticsTracking

      track_internal_event :show, name: 'view_group_security_inventory'

      def show; end

      private

      def authorize_read_security_inventory!
        render_403 unless can?(current_user, :read_security_inventory, group)
      end

      def tracking_namespace_source
        group
      end

      def tracking_project_source; end
    end
  end
end
