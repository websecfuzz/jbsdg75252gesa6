# frozen_string_literal: true

module GitlabSubscriptions
  module API
    module Internal
      class Members < ::API::Base
        feature_category :subscription_management
        urgency :low

        namespace :internal do
          namespace :gitlab_subscriptions do
            resource :namespaces, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
              before do
                @namespace = find_group(params[:id])

                not_found!('Group Namespace') unless @namespace.present?
              end

              desc 'Returns the direct owners of the namespace' do
                success Entities::Internal::Member
              end
              get ":id/owners" do
                owners = GroupMembersFinder.new(@namespace, params: { access_levels: ::Gitlab::Access::OWNER })
                  .execute(include_relations: [:direct])
                  .preload_users

                present paginate(owners), with: Entities::Internal::Member, namespace: @namespace
              end
            end
          end
        end
      end
    end
  end
end
