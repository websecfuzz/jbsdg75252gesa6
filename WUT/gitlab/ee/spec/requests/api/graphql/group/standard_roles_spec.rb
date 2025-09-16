# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).standardRoles', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group_a, refind: true) { create(:group, name: "group-a") }
  let_it_be(:group_aa) { create(:group, parent: group_a, name: "group-aa") }
  let_it_be(:group_aaa) { create(:group, parent: group_aa, name: "group-aaa") }
  let_it_be(:group_ab) { create(:group, parent: group_a, name: "group-ab") }
  let_it_be(:group_aba) { create(:group, parent: group_ab, name: "group-aba") }
  let_it_be(:group_b) { create(:group, name: "group-b") }
  let_it_be(:project_a) { create(:project, group: group_a, name: "a") }
  let_it_be(:project_aa) { create(:project, group: group_aa, name: "aa") }
  let_it_be(:project_aaa) { create(:project, group: group_aaa, name: "aaa") }
  let_it_be(:project_ab) { create(:project, group: group_ab, name: "ab") }
  let_it_be(:project_aba) { create(:project, group: group_aba, name: "aba") }

  let(:group) { group_a }
  let(:query) do
    %(
      query {
        group(fullPath: "#{group.full_path}") {
          standardRoles {
            nodes {
              name
              accessLevel
              membersCount
              usersCount
            }
          }
        }
      }
    )
  end

  let(:variables) { { full_path: group.full_path } }

  def run_query(query)
    run_with_clean_state(query, context: { current_user: current_user }, variables: variables)
  end

  context 'when the current user has access' do
    before do
      group.add_member(current_user, :owner)
    end

    context 'with project memberships' do
      before_all do
        create_list(:project_member, 2, :developer, project: project_aaa)
        create_list(:project_member, 2, :maintainer, project: project_ab)
        create_list(:project_member, 2, :owner, project: project_aba)
      end

      it 'returns the correct results' do
        data = run_query(query)
        expect(graphql_errors(data.to_h)).to be_blank

        [
          [::Gitlab::Access::MINIMAL_ACCESS, 0],
          [::Gitlab::Access::GUEST, 0],
          [::Gitlab::Access::PLANNER, 0],
          [::Gitlab::Access::REPORTER, 0],
          [::Gitlab::Access::DEVELOPER, 2],
          [::Gitlab::Access::MAINTAINER, 2],
          [::Gitlab::Access::OWNER, 1 + 2]
        ].each_with_index do |(access_level, count), index|
          item = graphql_dig_at(data, :data, :group, :standard_roles, :nodes, index)
          expect(item).to(match(a_hash_including(
            "accessLevel" => access_level,
            "membersCount" => count,
            "usersCount" => count
          )))
        end
      end
    end

    context 'with group memberships' do
      before_all do
        create_list(:group_member, 2, :developer, group: group_aaa)
        create_list(:group_member, 2, :maintainer, group: group_ab)
        create_list(:group_member, 2, :owner, group: group_aba)
      end

      it 'returns the correct results' do
        data = run_query(query)
        expect(graphql_errors(data.to_h)).to be_blank

        [
          [::Gitlab::Access::MINIMAL_ACCESS, 0],
          [::Gitlab::Access::GUEST, 0],
          [::Gitlab::Access::PLANNER, 0],
          [::Gitlab::Access::REPORTER, 0],
          [::Gitlab::Access::DEVELOPER, 2],
          [::Gitlab::Access::MAINTAINER, 2],
          [::Gitlab::Access::OWNER, 1 + 2]
        ].each_with_index do |(access_level, count), index|
          item = graphql_dig_at(data, :data, :group, :standard_roles, :nodes, index)
          expect(item).to(match(a_hash_including(
            "accessLevel" => access_level,
            "membersCount" => count,
            "usersCount" => count
          )))
        end
      end
    end

    context 'with group and project memberships' do
      before_all do
        create_list(:group_member, 2, :developer, group: group_aaa)
        create_list(:group_member, 2, :maintainer, group: group_ab)
        create_list(:group_member, 2, :owner, group: group_aba)
        create_list(:project_member, 3, :developer, project: project_aaa)
        create_list(:project_member, 3, :maintainer, project: project_ab)
        create_list(:project_member, 3, :owner, project: project_aba)
      end

      it 'returns the correct results' do
        data = run_query(query)
        expect(graphql_errors(data.to_h)).to be_blank

        [
          [::Gitlab::Access::MINIMAL_ACCESS, 0],
          [::Gitlab::Access::GUEST, 0],
          [::Gitlab::Access::PLANNER, 0],
          [::Gitlab::Access::REPORTER, 0],
          [::Gitlab::Access::DEVELOPER, 2 + 3],
          [::Gitlab::Access::MAINTAINER, 2 + 3],
          [::Gitlab::Access::OWNER, 1 + 2 + 3]
        ].each_with_index do |(access_level, count), index|
          item = graphql_dig_at(data, :data, :group, :standard_roles, :nodes, index)
          expect(item).to(match(a_hash_including(
            "accessLevel" => access_level,
            "membersCount" => count,
            "usersCount" => count
          )))
        end
      end

      it 'returns the results efficiently' do
        control = ActiveRecord::QueryRecorder.new do
          run_query(query)
        end

        create_list(:group_member, 2, :guest, group: group_a)
        create_list(:group_member, 2, :minimal_access, group: group_b)
        create_list(:group_member, 2, :reporter, group: group_aa)

        create(:project, group: group)

        create_list(:project_member, 3, :guest, project: project_a)
        create_list(:project_member, 3, :reporter, project: project_aa)

        expect do
          run_query(query)
        end.not_to exceed_query_limit(control)
      end
    end
  end
end
