# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretPermission, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user1) { create(:user) }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:client) { instance_double(SecretsManagement::SecretsManagerClient) }

  before_all do
    project.add_maintainer(user1)
  end

  before do
    secrets_manager.activate!
    allow(described_class).to receive(:client).and_return(client)
    allow(project).to receive(:secrets_manager).and_return(secrets_manager)
  end

  describe 'validations' do
    subject(:permission) do
      described_class.new(
        project: project,
        principal_type: 'User',
        principal_id: user1.id,
        resource_type: 'Project',
        resource_id: project.id,
        permissions: %w[create read]
      )
    end

    it 'is valid with valid attributes' do
      expect(permission).to be_valid
    end

    it 'requires a project with active secrets manager' do
      allow(secrets_manager).to receive(:active?).and_return(false)
      expect(permission).not_to be_valid
      expect(permission.errors[:base]).to include('Project secrets manager is not active.')
    end

    it 'validates presence of principal_id' do
      permission.principal_id = nil
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_id]).to include("can't be blank")
    end

    it 'validates presence of principal_type' do
      permission.principal_type = nil
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_type]).to include("can't be blank")
    end

    it 'validates presence of resource_id' do
      permission.resource_id = nil
      expect(permission).not_to be_valid
      expect(permission.errors[:resource_id]).to include("can't be blank")
    end

    it 'validates presence of resource_type' do
      permission.resource_type = nil
      expect(permission).not_to be_valid
      expect(permission.errors[:resource_type]).to include("can't be blank")
    end

    it 'validates presence of permissions' do
      permission.permissions = nil
      expect(permission).not_to be_valid
      expect(permission.errors[:permissions]).to include("can't be blank")
    end

    it 'validates non-empty permissions includes read' do
      permission.permissions = ['create']
      expect(permission).not_to be_valid
      expect(permission.errors[:permissions]).to include("must include read")
    end

    it 'validates principal_type is valid' do
      permission.principal_type = 'InvalidType'
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_type]).to include('must be one of: User, Role, Group, MemberRole')
    end

    it 'validates resource_type is valid' do
      permission.resource_type = 'InvalidType'
      expect(permission).not_to be_valid
      expect(permission.errors[:resource_type]).to include('must be one of: Project, Group')
    end

    it 'validates permissions are valid' do
      permission.permissions = ['invalid']
      expect(permission).not_to be_valid
      expect(permission.errors[:permissions]).to include('contains invalid permission: invalid')
    end

    it 'validates role_id when principal_type is Role' do
      e_msg = 'must be one of: {:guest=>10, :planner=>15, :reporter=>20, ' \
        ':developer=>30, :maintainer=>40} for Role type'

      permission.principal_type = 'Role'
      permission.principal_id = 999 # Invalid role ID
      expect(permission).not_to be_valid
      expect(permission.errors[:principal_id][0]).to eq(e_msg)
    end

    context 'when principal_type is Group' do
      it 'validates successfully when the group has access to the project' do
        permission.principal_id = group.id
        permission.principal_type = 'Group'
        expect(permission).to be_valid
      end

      it 'is invalid with random id' do
        permission.principal_id = 456
        permission.principal_type = 'Group'
        expect(permission).not_to be_valid
        expect(permission.errors[:principal_id]).to include('Group does not exist')
      end

      context 'when Project is not descendant of the Group' do
        let(:new_group) { create(:group) }

        it 'is invalid' do
          permission.principal_id = new_group.id
          permission.principal_type = 'Group'
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Group is not a descendant of the project')
        end
      end

      context 'with a group that has direct access to the project through project_group_links' do
        let(:test_group) { create(:group) }

        before do
          create(:project_group_link, project: project, group: test_group)
        end

        it 'is valid' do
          permission.principal_id = test_group.id
          permission.principal_type = 'Group'
          expect(permission).to be_valid
        end
      end
    end

    context 'when principal_type is MemberRole' do
      let(:member_role) { create(:member_role, namespace: role_namespace) }

      context 'with a valid member role for the group' do
        let(:role_namespace) { group }

        it 'does not add errors' do
          permission.principal_id = member_role.id
          permission.principal_type = 'MemberRole'

          expect(permission.errors).to be_empty
        end
      end

      context 'with an invalid member role for the group' do
        let(:another_group) { create(:group) }
        let(:role_namespace) { another_group }

        it 'does not add errors' do
          permission.principal_id = member_role.id
          permission.principal_type = 'MemberRole'
          expect(permission).not_to be_valid
          expect(permission.errors[:principal_id]).to include('Member Role does not have access to this project')
        end
      end
    end

    context 'when resource_type is Group' do
      context 'with an existing group' do
        before do
          group.add_member(user1, :owner)
        end

        it 'is valid' do
          permission.resource_type = 'Group'
          permission.resource_id = group.id
          expect(permission).to be_valid
        end
      end

      context 'with a non-existent group' do
        let(:resource_id) { 23433 }

        it 'is invalid' do
          permission.resource_type = 'Group'
          permission.resource_id = resource_id
          expect(permission).not_to be_valid
          expect(permission.errors[:resource_id]).to include('Group does not exist')
        end
      end
    end
  end
end
