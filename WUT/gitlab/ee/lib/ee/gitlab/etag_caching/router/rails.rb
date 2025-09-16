# frozen_string_literal: true

module EE
  module Gitlab
    module EtagCaching
      module Router
        module Rails
          extend ActiveSupport::Concern

          EE_ROUTE_DEFINITONS = [
            [
              %r{^/groups/#{::Gitlab::PathRegex.full_namespace_route_regex}/-/epics/\d+/realtime_changes\z},
              'epic_realtime_changes',
              ::Groups::EpicsController,
              :realtime_changes
            ],
            [
              %r{^/users/identity_verification/verification_state\z},
              'user_identity_verification_state',
              ::Users::RegistrationsIdentityVerificationController,
              :verification_state
            ],
            [
              %r{^/-/identity_verification/verification_state\z},
              'active_user_identity_verification_state',
              ::Users::IdentityVerificationController,
              :verification_state
            ]
          ].freeze

          class_methods do
            extend ::Gitlab::Utils::Override
            include ::Gitlab::Utils::StrongMemoize
            include ::Gitlab::EtagCaching::Router::Helpers

            override :all_routes
            def all_routes
              strong_memoize(:all_routes) do
                super + ee_routes
              end
            end

            def ee_routes
              EE_ROUTE_DEFINITONS.map { |route_definition| build_rails_route(*route_definition) }
            end
          end
        end
      end
    end
  end
end
