# frozen_string_literal: true

module Geo
  module Console
    # MainMenu is the typical entry point for the Geo console.
    class MainMenu < MultipleChoiceMenu
      def name
        <<~NAME.strip
          Main menu

          WARNING: This console contains unsafe commands. If you are not deeply familiar
          with the code and its risks, then DO NOT RUN IT on a production environment.
        NAME
      end

      def choices
        [
          TroubleshootReplicationOrVerificationMenu.new(**next_choice_args),
          (ShowCachedSecondarySiteStatusAction.new(**next_choice_args) if Gitlab::Geo.secondary?),
          (ShowUncachedSecondarySiteStatusAction.new(**next_choice_args) if Gitlab::Geo.secondary?),
          ShowAllSiteStatusDataAction.new(**next_choice_args),
          Exit.new
        ]
      end
    end
  end
end
