# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::MergeRequests::GroupComplianceViolationResolver,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:project2) { create(:project, :repository, group: group) }
  let_it_be(:project_outside_group) { create(:project, :repository, group: create(:group)) }
  let_it_be(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, state: :merged, title: 'abcd')
  end

  let_it_be(:merge_request2) do
    create(:merge_request, source_project: project2, target_project: project2, state: :merged, title: 'zyxw')
  end

  let_it_be(:merge_request_outside_group) do
    create(:merge_request, source_project: project_outside_group, target_project: project_outside_group, state: :merged)
  end

  let_it_be(:compliance_violation) do
    create(:compliance_violation, :approved_by_committer, severity_level: :low, merge_request: merge_request,
      title: 'abcd', target_project_id: project.id, target_branch: merge_request.target_branch, merged_at: 3.days.ago)
  end

  let_it_be(:compliance_violation2) do
    create(:compliance_violation, :approved_by_merge_request_author, severity_level: :high,
      merge_request: merge_request2, title: 'zyxw', target_project_id: project2.id,
      target_branch: merge_request2.target_branch, merged_at: 1.day.ago)
  end

  let_it_be(:compliance_violation_outside_group) do
    create(:compliance_violation, :approved_by_committer, merge_request: merge_request_outside_group,
      title: merge_request_outside_group.title, target_project_id: project_outside_group.id,
      target_branch: merge_request_outside_group.target_branch)
  end

  before do
    stub_licensed_features(
      group_level_compliance_violations_report: true
    )
    merge_request.metrics.update!(merged_at: 3.days.ago)
    merge_request2.metrics.update!(merged_at: 1.day.ago)
  end

  describe '#resolve' do
    let(:args) { {} }
    let(:obj) { group }
    let(:filter_results) { ->(violations) { violations } }

    subject(:resolve_compliance_violations) do
      resolve(described_class, obj: obj, args: args, ctx: { current_user: current_user })
    end

    it_behaves_like 'violations resolver'

    context 'when user is authorized when filtering and given an array of project IDs' do
      before do
        obj.add_owner(current_user)
      end

      let(:args) { { filters: { project_ids: [::Gitlab::GlobalId.as_global_id(project.id, model_name: 'Project')] } } }

      it 'finds the filtered compliance violations' do
        expect(resolve_compliance_violations).to contain_exactly(compliance_violation)
      end
    end
  end
end
