# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.instance_standard_role', feature_category: :system_access do
  include GraphqlHelpers

  def standard_roles_query
    <<~QUERY
    {
      standardRoles {
        nodes {
          accessLevel
          name
          membersCount
          usersCount
          detailsPath
        }
      }
    }
    QUERY
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:member_1) { create(:group_member, :guest, user: user) }
  let_it_be(:member_2) { create(:group_member, :maintainer, user: user) }
  let_it_be(:member_3) { create(:project_member, :guest, user: user) }
  let_it_be(:member_4) { create(:group_member, :planner, user: user) }

  subject(:roles) do
    graphql_data.dig('standardRoles', 'nodes')
  end

  before do
    post_graphql(standard_roles_query, current_user: user)
  end

  context 'when on SaaS', :saas do
    it 'returns error' do
      expect_graphql_errors_to_include('You have to specify group for SaaS.')
    end
  end

  context 'when on self-managed' do
    it_behaves_like 'a working graphql query'

    it 'returns all standard-level roles with counts' do
      expected_result = [
        {
          'accessLevel' => 5,
          'name' => 'Minimal Access',
          'membersCount' => 0,
          'usersCount' => 0,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/MINIMAL_ACCESS'
        },
        {
          'accessLevel' => 10,
          'name' => 'Guest',
          'membersCount' => 2,
          'usersCount' => 1,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/GUEST'
        },
        {
          'accessLevel' => 15,
          'name' => 'Planner',
          'membersCount' => 1,
          'usersCount' => 1,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/PLANNER'
        },
        {
          'accessLevel' => 20,
          'name' => 'Reporter',
          'membersCount' => 0,
          'usersCount' => 0,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/REPORTER'
        },
        {
          'accessLevel' => 30,
          'name' => 'Developer',
          'membersCount' => 0,
          'usersCount' => 0,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/DEVELOPER'
        },
        {
          'accessLevel' => 40,
          'name' => 'Maintainer',
          'membersCount' => 1,
          'usersCount' => 1,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/MAINTAINER'
        },
        # one owner is created during project creation
        {
          'accessLevel' => 50,
          'name' => 'Owner',
          'membersCount' => 1,
          'usersCount' => 1,
          'detailsPath' => '/admin/application_settings/roles_and_permissions/OWNER'
        }
      ]

      expect(roles).to eq(expected_result)
    end
  end
end
