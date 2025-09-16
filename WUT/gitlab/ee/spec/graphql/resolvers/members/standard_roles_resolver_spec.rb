# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Members::StandardRolesResolver, feature_category: :api do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) do
      resolve(described_class, obj: group, args: args, lookahead: positive_lookahead, arg_style: :internal)
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:user2) { create(:user) }

    before do
      group.add_member(user, ::Gitlab::Access::MAINTAINER)
      group.add_member(user2, ::Gitlab::Access::DEVELOPER)
    end

    context 'when a user has maintainer access' do
      let_it_be(:args) { nil }

      it 'returns the totals for each standard role' do
        expect(result).to be_present
        expect(result.count).to eq(7)

        roles_with_members = [::Gitlab::Access::MAINTAINER, ::Gitlab::Access::DEVELOPER]

        ::Gitlab::Access.options_with_minimal_access.sort_by { |_, v| v }.each_with_index do |(name, value), index|
          role = result[index]
          expect(role[:access_level]).to eq(value)
          expect(role[:name]).to eq(name)
          expect(role[:members_count]).to eq(roles_with_members.include?(value) ? 1 : 0)
          expect(role[:users_count]).to eq(roles_with_members.include?(value) ? 1 : 0)
          expect(role[:group]).to eq(group)
        end
      end
    end

    context 'when filtering by a single access_level' do
      let_it_be(:args) { { access_level: [::Gitlab::Access::MAINTAINER] } }

      it 'returns only the specified role' do
        expect(result.count).to eq(1)

        role = result.first
        expect(role[:access_level]).to eq(::Gitlab::Access::MAINTAINER)
        expect(role[:members_count]).to eq(1)
        expect(role[:users_count]).to eq(1)
      end
    end
  end
end
