# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProjectCreateService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:group) { create(:group, path: 'target-group', name: 'Target Group') }

    let_it_be_with_refind(:project) do
      create(:project, path: 'target-project', name: 'Target Project', group: group)
    end

    let_it_be(:owner) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:developer) { create(:user) }

    let(:expected_readme_data) do
      path = "ee/spec/fixtures/projects/security/policies/expected_readme_for_#{container.class.name.downcase}.md"
      File.read(Rails.root.join(path))
    end

    let(:current_user) { owner }
    let(:container) { project }

    subject(:service) { described_class.new(container: container, current_user: current_user) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      group.add_owner(owner)
      container.add_owner(owner)
    end

    context 'when security_orchestration_policies_configuration does not exist for project' do
      before_all do
        project.add_maintainer(maintainer)
        project.add_developer(developer)
      end

      it 'creates policy project with maintainers and developers from target project as developers allowing merge request author approval', :aggregate_failures do
        response = service.execute

        policy_project = response[:policy_project]
        expect(project.reload.security_orchestration_policy_configuration.security_policy_management_project).to eq(policy_project)
        expect(policy_project.namespace).to eq(project.namespace)
        expect(policy_project.team.developers).to contain_exactly(maintainer, developer)
        expect(policy_project.container_registry_access_level).to eq(ProjectFeature::DISABLED)
        expect(policy_project.merge_requests_author_approval).to be_truthy
        expect(policy_project.repository.readme.data).to eq(expected_readme_data)
      end

      context 'when there is already a security policy project created in this namespace' do
        before do
          create(:project, namespace: project.namespace, name: "#{project.name} - Security policy project")
        end

        it 'returns error' do
          response = service.execute

          expect(response[:status]).to eq(:error)
          expect(response[:message]).to eq('Security Policy project already exists, but is not linked.')
        end
      end
    end

    context 'when security_orchestration_policies_configuration does not exist for namespace' do
      let(:container) { group }

      before_all do
        group.add_maintainer(maintainer)
        group.add_developer(developer)
      end

      it 'creates policy project with maintainers and developers from target group as developers', :aggregate_failures do
        response = service.execute

        policy_project = response[:policy_project]
        expect(group.reload.security_orchestration_policy_configuration.security_policy_management_project).to eq(policy_project)
        expect(policy_project.namespace).to eq(group)
        expect(policy_project.owner).to eq(group)
        expect(MembersFinder.new(policy_project, nil).execute.map(&:user)).to contain_exactly(owner, maintainer, developer)
        expect(policy_project.container_registry_access_level).to eq(ProjectFeature::DISABLED)
        expect(policy_project.repository.readme.data).to eq(expected_readme_data)
      end
    end

    context 'when user is added as maintainer to both group and the project' do
      let(:current_user) { owner }

      before_all do
        group.add_maintainer(maintainer)
        project.add_maintainer(maintainer)
      end

      it 'successfully create projects without errors' do
        response = service.execute

        expect(response[:status]).to eq(:success)
      end
    end

    context 'when adding users to security policy project fails' do
      before_all do
        project.add_maintainer(maintainer)
      end

      before do
        errors = ActiveModel::Errors.new(ProjectMember.new).tap { |e| e.add(:source, "cannot be nil") }
        error_member = ProjectMember.new
        allow(error_member).to receive(:errors).and_return(errors)
        allow(service).to receive(:add_members).and_return([error_member])
      end

      it 'returns error' do
        response = service.execute

        expect(response[:status]).to eq(:error)
        expect(response[:message]).to eq('Project was created and assigned as security policy project, but failed adding users to the project.')
      end
    end

    context 'when project creation fails' do
      let(:error_message) { "Path can't be blank" }

      let(:invalid_project) do
        instance_double(
          ::Project,
          saved?: false,
          errors: instance_double(ActiveModel::Errors, full_messages: [error_message])
        )
      end

      before do
        allow_next_instance_of(::Projects::CreateService) do |service|
          allow(service).to receive(:execute).and_return(invalid_project)
        end
      end

      it 'returns error' do
        response = service.execute

        expect(response[:status]).to eq(:error)
        expect(response[:message]).to eq(error_message)
      end
    end

    context 'when security_orchestration_policies_configuration already exists for project' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

      it 'returns error' do
        response = service.execute

        expect(response[:status]).to eq(:error)
        expect(response[:message]).to eq('Security Policy project already exists.')
      end
    end

    context 'when user does not have permission to create project in container' do
      let(:container) { group }

      before do
        group.update_attribute(:project_creation_level, Gitlab::Access::NO_ACCESS)
      end

      it 'returns error' do
        response = service.execute

        expect(response[:status]).to be(:error)
        expect(response[:message]).to eq('User does not have permission to create a Security Policy project.')
      end
    end
  end
end
