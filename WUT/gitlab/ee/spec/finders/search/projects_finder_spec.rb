# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectsFinder, feature_category: :global_search do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    subject(:execute) { described_class.new(user: user).execute }

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has no matching projects' do
      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has direct membership to a project' do
      it 'returns that project' do
        project.add_developer(user)

        expect(execute).to contain_exactly(project)
      end
    end

    context 'when user has direct membership to the project parent group' do
      it 'returns nothing' do
        group.add_developer(user)

        expect(execute).to be_empty
      end
    end

    context 'when user has membership through a shared group link' do
      it 'does not return that project' do
        shared_with_group = create(:group, developers: user)
        create(:group_group_link, shared_with_group: shared_with_group, shared_group: group)

        expect(execute).to be_empty
      end
    end

    context 'when user has membership through a shared project group link' do
      let_it_be(:shared_with_group) { create(:group, developers: user) }
      let_it_be_with_reload(:project_group_link) do
        create(:project_group_link, project: project, group: shared_with_group)
      end

      it 'returns that project' do
        expect(execute).to contain_exactly(project)
      end

      context 'and the project group link is expired' do
        it 'returns nothing' do
          project_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to be_empty
        end
      end
    end
  end
end
