# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MembersFinder, feature_category: :groups_and_projects do
  context 'when filtering by max role' do
    let_it_be(:group) { create :group }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:member_role) { create(:member_role, :guest, namespace: group) }
    let_it_be(:member_with_custom_role) { create(:project_member, :guest, project: project, member_role: member_role) }
    let_it_be(:member_without_custom_role) { create(:project_member, :guest, project: project) }

    subject(:by_max_role) { described_class.new(project, create(:user), params: { max_role: max_role }).execute }

    context 'when filtering by custom role ID' do
      describe 'provided member role ID is incorrect' do
        using RSpec::Parameterized::TableSyntax

        where(:max_role) { [nil, '', lazy { "xcustom-#{member_role.id}" }, lazy { "custom-#{member_role.id}x" }] }

        with_them do
          it { is_expected.to match_array(project.members) }
        end
      end

      describe 'none of the members have the provided member role ID' do
        let(:max_role) { "custom-#{non_existing_record_id}" }

        it { is_expected.to be_empty }
      end

      describe 'one of the members has the provided member role ID' do
        let(:max_role) { "custom-#{member_role.id}" }

        it { is_expected.to contain_exactly(member_with_custom_role) }
      end
    end
  end
end
