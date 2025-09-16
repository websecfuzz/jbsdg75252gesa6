# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManager, feature_category: :secrets_management do
  subject(:secrets_manager) { build(:project_secrets_manager) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }

  describe 'state machine' do
    context 'when newly created' do
      it 'defaults to provisioning' do
        secrets_manager.save!
        expect(secrets_manager).to be_provisioning
      end
    end

    context 'when activated' do
      it 'becomes active' do
        secrets_manager.save!
        secrets_manager.activate!
        expect(secrets_manager.reload).to be_active
      end
    end
  end

  describe '#ci_policies' do
    let_it_be(:project) { create(:project) }
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    describe '#ci_policy_name_global' do
      it 'returns the correct global policy name' do
        expect(secrets_manager.ci_policy_name_global).to eq("project_#{project.id}/pipelines/global")
      end
    end

    describe '#ci_policy_name_env' do
      it 'returns the correct environment policy name with hex-encoded environment' do
        environment = 'production'
        hex_env = environment.unpack1('H*')

        expect(secrets_manager.ci_policy_name_env(environment)).to eq("project_#{project.id}/pipelines/env/#{hex_env}")
      end

      it 'handles special characters in environment names' do
        environment = 'staging/us-east-1'
        hex_env = environment.unpack1('H*')

        expect(secrets_manager.ci_policy_name_env(environment)).to eq("project_#{project.id}/pipelines/env/#{hex_env}")
      end
    end

    describe '#ci_policy_name_branch' do
      it 'returns the correct branch policy name with hex-encoded branch' do
        branch = 'main'
        hex_branch = branch.unpack1('H*')
        policy_name = "project_#{project.id}/pipelines/branch/#{hex_branch}"

        expect(secrets_manager.ci_policy_name_branch(branch)).to eq(policy_name)
      end

      it 'handles special characters in branch names' do
        branch = 'feature/add-new-widget'
        hex_branch = branch.unpack1('H*')
        policy_name = "project_#{project.id}/pipelines/branch/#{hex_branch}"

        expect(secrets_manager.ci_policy_name_branch(branch)).to eq(policy_name)
      end
    end

    describe '#ci_policy_name_combined' do
      it 'returns the correct combined policy name with hex-encoded environment and branch' do
        environment = 'production'
        branch = 'main'
        hex_env = environment.unpack1('H*')
        hex_branch = branch.unpack1('H*')

        expected = "project_#{project.id}/pipelines/combined/env/#{hex_env}/branch/#{hex_branch}"
        expect(secrets_manager.ci_policy_name_combined(environment, branch)).to eq(expected)
      end

      it 'handles special characters in environment and branch names' do
        environment = 'staging/us-east-1'
        branch = 'feature/add-new-widget'
        hex_env = environment.unpack1('H*')
        hex_branch = branch.unpack1('H*')

        expected = "project_#{project.id}/pipelines/combined/env/#{hex_env}/branch/#{hex_branch}"
        expect(secrets_manager.ci_policy_name_combined(environment, branch)).to eq(expected)
      end
    end

    describe '#ci_auth_literal_policies' do
      it 'returns an array with all policy types' do
        policies = secrets_manager.ci_auth_literal_policies

        expect(policies.size).to eq(4)
        expect(policies[0]).to eq("project_#{project.id}/pipelines/global") # Global policy
        expect(policies[1]).to eq(secrets_manager.ci_policy_template_literal_environment)
        expect(policies[2]).to eq(secrets_manager.ci_policy_template_literal_branch)
        expect(policies[3]).to eq(secrets_manager.ci_policy_template_literal_combined)
      end
    end

    describe '#ci_auth_glob_policies' do
      context 'with environment glob and literal branch' do
        let(:environment) { 'prod-*' }
        let(:branch) { 'main' }

        it 'returns environment glob and combined environment glob with branch policies' do
          policies = secrets_manager.ci_auth_glob_policies(environment, branch)

          expect(policies.size).to eq(2)
          expect(policies[0]).to eq(secrets_manager.ci_policy_template_glob_environment(environment))
          expect(policies[1]).to eq(secrets_manager.ci_policy_template_combined_glob_environment_branch(environment,
            branch))
        end
      end

      context 'with literal environment and branch glob' do
        let(:environment) { 'production' }
        let(:branch) { 'feature-*' }

        it 'returns branch glob and combined environment with branch glob policies' do
          policies = secrets_manager.ci_auth_glob_policies(environment, branch)

          expect(policies.size).to eq(2)
          expect(policies[0]).to eq(secrets_manager.ci_policy_template_glob_branch(branch))
          expect(policies[1]).to eq(secrets_manager.ci_policy_template_combined_environment_glob_branch(environment,
            branch))
        end
      end

      context 'with both environment and branch globs' do
        let(:environment) { 'prod-*' }
        let(:branch) { 'feature-*' }

        it 'returns environment glob, branch glob, and combined glob policies' do
          policies = secrets_manager.ci_auth_glob_policies(environment, branch)

          expect(policies.size).to eq(3)
          expect(policies[0]).to eq(secrets_manager.ci_policy_template_glob_environment(environment))
          expect(policies[1]).to eq(secrets_manager.ci_policy_template_glob_branch(branch))
          expect(policies[2]).to eq(secrets_manager.ci_policy_template_combined_glob_environment_glob_branch(
            environment, branch))
        end
      end

      context 'with no globs' do
        let(:environment) { 'production' }
        let(:branch) { 'main' }

        it 'returns an empty array' do
          policies = secrets_manager.ci_auth_glob_policies(environment, branch)

          expect(policies).to be_empty
        end
      end
    end

    describe '#ci_policy_template_glob_environment' do
      it 'returns a template that checks for matching environment with hex encoding' do
        env_glob = 'prod-*'
        env_glob_hex = env_glob.unpack1('H*')

        template = secrets_manager.ci_policy_template_glob_environment(env_glob)

        expect(template).to include("(eq \"#{env_glob_hex}\" (.environment | hex))")
        expect(template).to include(secrets_manager.ci_policy_name_env(env_glob))
      end
    end

    describe '#ci_policy_template_glob_branch' do
      it 'returns a template that checks for matching branch with hex encoding' do
        branch_glob = 'feature-*'
        branch_glob_hex = branch_glob.unpack1('H*')

        template = secrets_manager.ci_policy_template_glob_branch(branch_glob)

        expect(template).to include("(eq \"#{branch_glob_hex}\" (.ref | hex))")
        expect(template).to include(secrets_manager.ci_policy_name_branch(branch_glob))
      end
    end

    describe '#ci_policy_template_combined_glob_environment_branch' do
      it 'returns a template that checks for matching environment glob with literal branch' do
        env_glob = 'prod-*'
        branch_literal = 'main'
        env_glob_hex = env_glob.unpack1('H*')

        template = secrets_manager.ci_policy_template_combined_glob_environment_branch(env_glob, branch_literal)

        expect(template).to include("(eq \"#{env_glob_hex}\" (.environment | hex))")
        expect(template).to include(secrets_manager.ci_policy_name_combined(env_glob, branch_literal))
      end
    end

    describe '#ci_policy_template_combined_environment_glob_branch' do
      it 'returns a template that checks for matching branch glob with literal environment' do
        env_literal = 'production'
        branch_glob = 'feature-*'
        branch_glob_hex = branch_glob.unpack1('H*')

        template = secrets_manager.ci_policy_template_combined_environment_glob_branch(env_literal, branch_glob)

        expect(template).to include("(eq \"#{branch_glob_hex}\" (.ref | hex))")
        expect(template).to include(secrets_manager.ci_policy_name_combined(env_literal, branch_glob))
      end
    end

    describe '#ci_policy_template_combined_glob_environment_glob_branch' do
      it 'returns a template that checks for matching environment and branch globs' do
        env_glob = 'prod-*'
        branch_glob = 'feature-*'
        env_glob_hex = env_glob.unpack1('H*')
        branch_glob_hex = branch_glob.unpack1('H*')

        template = secrets_manager.ci_policy_template_combined_glob_environment_glob_branch(env_glob, branch_glob)

        expect(template).to include("(eq \"#{env_glob_hex}\" (.environment | hex))")
        expect(template).to include("(eq \"#{branch_glob_hex}\" (.ref | hex))")
        expect(template).to include(secrets_manager.ci_policy_name_combined(env_glob, branch_glob))
      end
    end
  end

  describe '#ci_secrets_mount_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_secrets_mount_path }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'includes the namespace type and ID in the path' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv")
      end
    end
  end

  describe '#ci_data_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_data_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("explicit/DB_PASS")
      end
    end
  end

  describe '#ci_full_path' do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_full_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it 'does not include any namespace information' do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it 'does not include any namespace information' do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv/data/explicit/DB_PASS")
      end
    end
  end

  describe "#ci_metadata_full_path" do
    let(:secrets_manager) { build(:project_secrets_manager, project: project) }

    subject(:path) { secrets_manager.ci_metadata_full_path("DB_PASS") }

    context 'when the project belongs to a user namespace' do
      let_it_be(:project) { create(:project) }

      it "returns the correct metadata path" do
        expect(path).to eq("user_#{project.namespace.id}/project_#{project.id}/secrets/kv/metadata/explicit/DB_PASS")
      end
    end

    context 'when the project belongs to a group namespace' do
      let_it_be(:project) { create(:project, :in_group) }

      it "returns the correct metadata path" do
        expect(path).to eq("group_#{project.namespace.id}/project_#{project.id}/secrets/kv/metadata/explicit/DB_PASS")
      end
    end
  end

  describe '#ci_jwt' do
    let_it_be(:project) { create(:project) }
    let_it_be(:secrets_manager) { build(:project_secrets_manager, project: project) }
    let_it_be(:ci_build) { create(:ci_build, project: project) }
    let_it_be(:openbao_server_url) { described_class.server_url }

    subject(:ci_jwt) { secrets_manager.ci_jwt(ci_build) }

    before do
      allow(Gitlab::Ci::JwtV2).to receive(:for_build).with(ci_build, aud: openbao_server_url)
      .and_return("generated_jwt_id_token_for_secrets_manager")
    end

    it 'generates a JWT for the build' do
      expect(ci_jwt).to eq("generated_jwt_id_token_for_secrets_manager")
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'generate_id_token_for_secrets_manager_authentication' }
      let(:category) { described_class.name }
      let(:namespace) { project.namespace }
      let(:user) { ci_build.user }
    end
  end

  describe 'policy name generation' do
    let_it_be(:project) { create(:project) }

    subject(:test_subject) do
      described_class.new.send(:generate_policy_name, project_id: project.id, principal_type: principal_type,
        principal_id: principal_id)
    end

    context 'for User principal type' do
      let(:principal_type) { 'User' }
      let(:principal_id) { 123 }

      it 'generates the correct policy name' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/user_123")
      end
    end

    context 'for Role principal type' do
      let(:principal_type) { 'Role' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with role ID' do
        expect(test_subject).to eq("project_#{project.id}/users/roles/3")
      end
    end

    context 'for MemberRole principal type' do
      let(:principal_type) { 'MemberRole' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with member role ID' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/member_role_3")
      end
    end

    context 'for Group principal type' do
      let(:principal_type) { 'Group' }
      let(:principal_id) { 3 }

      it 'generates the correct policy name with group ID' do
        expect(test_subject).to eq("project_#{project.id}/users/direct/group_3")
      end
    end
  end
end
