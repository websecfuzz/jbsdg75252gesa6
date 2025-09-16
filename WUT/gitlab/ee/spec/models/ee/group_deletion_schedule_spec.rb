# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupDeletionSchedule, feature_category: :groups_and_projects do
  describe 'Validations' do
    context 'when containing linked security policy project' do
      subject(:deletion_schedule) { group.build_deletion_schedule.tap(&:validate) }

      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:policy_project) { create(:project, group: subgroup) }
      let_it_be(:policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          namespace: subgroup,
          project: nil,
          security_policy_management_project: policy_project
        )
      end

      context 'with licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        specify do
          expect(deletion_schedule.errors[:base])
            .to include('Group cannot be deleted because it has projects that are linked as a security policy project')
        end
      end

      context 'without licensed feature' do
        specify do
          expect(deletion_schedule.errors[:base]).to be_empty
        end
      end
    end
  end
end
