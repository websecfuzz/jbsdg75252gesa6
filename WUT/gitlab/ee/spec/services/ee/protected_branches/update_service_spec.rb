# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranches::UpdateService, feature_category: :compliance_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:branch_name) { 'feature' }
  let(:protected_branch) { create(:protected_branch, name: branch_name, project: project) }
  let(:user) { project.first_owner }

  subject(:service) { described_class.new(project, user, params) }

  describe '#execute' do
    context 'with invalid params' do
      let(:params) do
        {
          name: branch_name,
          push_access_levels_attributes: [{ access_level: Gitlab::Access::MAINTAINER }]
        }
      end

      it "does not add a security audit event entry" do
        expect { service.execute(protected_branch) }.not_to change(::AuditEvent, :count)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          name: branch_name,
          merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
          push_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }]
        }
      end

      it 'adds security audit event entries' do
        expect { service.execute(protected_branch) }.to change(::AuditEvent, :count).by(2)
      end
    end
  end

  describe 'blocking scan result policies' do
    context 'with project-level protected branch' do
      let(:params) { { name: branch_name.reverse } }

      let(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      include_context 'with approval policy blocking protected branches'

      before do
        create(:scan_result_policy_read, :blocking_protected_branches, project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'raises' do
        expect { service.execute(protected_branch) }.to raise_error(::Gitlab::Access::AccessDeniedError)
      end
    end

    context 'with group-level protected branch' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:protected_branch) { create(:protected_branch, project_id: nil, namespace_id: group.id) }

      before_all do
        group.add_owner(user)
      end

      context 'with blocking scan result policy' do
        let(:params) { { name: branch_name.reverse } }

        let(:policy_configuration) do
          create(:security_orchestration_policy_configuration, :namespace, namespace_id: group.id)
        end

        shared_examples 'prevents update of protected branch' do
          it 'raises' do
            expect { service.execute(protected_branch) }.to raise_error(::Gitlab::Access::AccessDeniedError)
          end
        end

        include_context 'with approval policy blocking protected branches' do
          include_examples 'prevents update of protected branch'
        end

        include_context 'with approval policy blocking group-level protected branches' do
          include_examples 'prevents update of protected branch'
        end
      end
    end
  end
end
