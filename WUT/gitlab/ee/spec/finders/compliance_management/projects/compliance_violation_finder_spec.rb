# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolationFinder, feature_category: :compliance_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: root_group) }
  let_it_be(:subgroup_project) { create(:project, group: sub_group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework) { create(:compliance_framework, namespace: root_group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: root_group, framework: framework) }
  let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:control2) { create(:compliance_requirements_control, :external, compliance_requirement: requirement) }
  let_it_be(:control3) do
    create(:compliance_requirements_control, :default_branch_protected, compliance_requirement: requirement)
  end

  let_it_be(:other_framework) { create(:compliance_framework, namespace: other_group) }
  let_it_be(:other_requirement) { create(:compliance_requirement, namespace: other_group, framework: other_framework) }
  let_it_be(:other_control) { create(:compliance_requirements_control, compliance_requirement: other_requirement) }

  let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: root_group_project.id) }
  let_it_be(:audit_event2) { create(:audit_events_group_audit_event, group_id: root_group.id) }
  let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: other_project.id) }

  let_it_be(:violation1) do
    create(:project_compliance_violation, namespace: root_group_project.namespace, project: root_group_project,
      audit_event_id: audit_event1.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control1,
      status: 0
    )
  end

  let_it_be(:violation2) do
    create(:project_compliance_violation, namespace: root_group_project.namespace, project: root_group_project,
      audit_event_id: audit_event1.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control2,
      status: 1
    )
  end

  let_it_be(:violation3) do
    create(:project_compliance_violation, namespace: root_group_project.namespace, project: root_group_project,
      audit_event_id: audit_event2.id,
      audit_event_table_name: :group_audit_events,
      compliance_control: control1,
      status: 2,
      created_at: 1.day.ago
    )
  end

  let_it_be(:violation4) do
    create(:project_compliance_violation, namespace: subgroup_project.namespace, project: subgroup_project,
      audit_event_id: audit_event2.id,
      audit_event_table_name: :group_audit_events,
      compliance_control: control3,
      status: 3
    )
  end

  let_it_be(:violation5) do
    create(:project_compliance_violation, namespace: other_project.namespace, project: other_project,
      audit_event_id: audit_event3.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: other_control,
      status: 0
    )
  end

  subject(:finder_response) { described_class.new(root_group, user).execute }

  describe '#execute' do
    before_all do
      root_group.add_owner(user)
      other_group.add_owner(user)
    end

    context 'when the group is not licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: false)
      end

      it { is_expected.to eq([]) }
    end

    context 'when the group is licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: true)
      end

      context 'when user is not allowed to view the dashboard' do
        before_all do
          root_group.add_maintainer(user)
        end

        it { is_expected.to eq([]) }
      end

      context 'when user is allowed to view the dashboard' do
        it 'returns list of compliance violations for all projects under the group in created_at order' do
          expect(finder_response.to_a).to eq([violation4, violation2, violation1, violation3])
        end

        it 'does not return compliance violations which are not under root group' do
          expect(finder_response.to_a).to exclude(violation5)
        end

        context 'for subgroup' do
          subject(:finder_response) { described_class.new(sub_group, user).execute }

          it 'returns list of compliance violations for projects under subgroup' do
            expect(finder_response.to_a).to eq([violation4])
          end
        end
      end
    end
  end
end
