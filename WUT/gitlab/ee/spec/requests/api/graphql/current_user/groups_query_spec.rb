# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query current user groups', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:root_parent) { create(:group, :private, name: 'root-1', path: 'root-1', organization: organization) }
  let_it_be(:guest_group) { create(:group, name: 'public guest', path: 'public-guest', guests: user, organization: organization) }
  let_it_be(:private_maintainer_group) { create(:group, :private, name: 'b private maintainer', path: 'b-private-maintainer', parent: root_parent, maintainers: user, organization: organization) }
  let_it_be(:private_developer_group) { create(:group, :private, project_creation_level: nil, name: 'c public developer', path: 'c-public-developer', developers: user, organization: organization) }
  let_it_be(:public_maintainer_group) { create(:group, :private, name: 'a public maintainer', path: 'a-public-maintainer', maintainers: user, organization: organization) }

  let(:group_arguments) { {} }
  let(:current_user) { user }

  let(:fields) do
    <<~GRAPHQL
      nodes { id path fullPath name }
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', {}, query_graphql_field('groups', group_arguments, fields))
  end

  shared_examples 'no N + 1 DB queries' do
    it 'avoids N+1 queries', :request_store do
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      create(:group, :private, maintainers: current_user, organization: organization)
      create(:group, :private, parent: private_maintainer_group, organization: organization)

      another_root = create(:group, :private, name: 'root-3', path: 'root-3', organization: organization)
      create(:group, :private, parent: another_root, maintainers: current_user, organization: organization)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'when permission_scope is CREATE_PROJECTS' do
    let(:group_arguments) { { permission_scope: :CREATE_PROJECTS } }

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a working graphql query'

    context 'when ip_restrictions feature is enabled' do
      before do
        stub_licensed_features(group_ip_restriction: true)
      end

      context 'when check_namespace_plan setting is enabled' do
        before do
          stub_application_setting(check_namespace_plan: true)
        end

        it_behaves_like 'no N + 1 DB queries'
      end

      context 'when check_namespace_plan setting is disabled' do
        before do
          stub_application_setting(check_namespace_plan: false)
        end

        it_behaves_like 'no N + 1 DB queries'
      end
    end
  end
end
