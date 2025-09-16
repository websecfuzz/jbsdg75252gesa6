# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceVariablePolicy, feature_category: :workspaces do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:agent_project_creator, refind: true) { create(:user) }
  let_it_be(:agent_project, refind: true) { create(:project, creator: agent_project_creator) }
  let_it_be(:agent, refind: true) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be(:workspace_project_creator, refind: true) { create(:user) }
  let_it_be(:workspace_project, refind: true) { create(:project, creator: workspace_project_creator) }
  let_it_be(:workspace_owner, refind: true) { create(:user) }
  let_it_be(:workspace, refind: true) do
    create(:workspace, project: workspace_project, agent: agent, user: workspace_owner)
  end

  let_it_be(:workspace_variable, refind: true) do
    create(:workspace_variable, workspace: workspace)
  end

  let_it_be(:admin_user, refind: true) { create(:admin) }
  let_it_be(:non_admin_user, refind: true) { create(:user) }
  # NOTE: The following need to be `let`, not `let_it_be`, because it uses a `let` declaration from the matrix
  let(:user) { admin_mode ? admin_user : non_admin_user }

  let(:policy_class) { described_class }

  subject(:policy_instance) { policy_class.new(user, workspace_variable) }

  before do
    stub_licensed_features(remote_development: licensed)
    enable_admin_mode!(user) if admin_mode
    workspace.update!(user: user) if workspace_owner
    agent_project.add_role(user, role_on_agent_project) unless role_on_agent_project == :none
    agent_project.reload
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31543
    workspace_project.add_role(user, role_on_workspace_project) unless role_on_workspace_project == :none
    workspace_project.reload
    user.reload

    debug = false # Set to true to enable debugging of policies, but change back to false before committing
    # noinspection RubyMismatchedArgumentType -- We are passing a QA::Resource::User test double
    debug_policies(user, workspace_variable, policy_class, ability) if debug
  end

  shared_examples 'fixture sanity checks' do
    # noinspection RubyResolve -- Rubymine is incorrectly resolving workspace_project as `QA::Resource::Project`.
    it "has fixture sanity checks" do
      expect(agent_project.creator_id).not_to eq(workspace_project.creator_id)
      expect(agent_project.creator_id).not_to eq(user.id)
      expect(workspace_project.creator_id).not_to eq(user.id)
      expect(agent.created_by_user_id).not_to eq(workspace.user_id)
      expect(workspace.user_id).not_to eq(user.id) unless workspace_owner
    end
  end

  # rubocop:disable Layout/LineLength -- TableSyntax should not be split across lines
  where(:admin, :admin_mode, :licensed, :workspace_owner, :role_on_workspace_project, :role_on_agent_project, :allowed) do
    # @formatter:off - Turn off RubyMine autoformatting

    # admin      | # admin_mode | # licensed | workspace_owner | role_on_workspace_project | role_on_agent_project | allowed  # check
    true         | true         | false      | false           | :none                     | :none                 | false    # admin_mode enabled but not licensed: not allowed
    false        | false        | false      | true            | :developer                | :none                 | false    # Workspace owner and project developer but not licensed: not allowed
    false        | false        | true       | true            | :guest                    | :none                 | false    # Workspace owner but project guest: not allowed
    false        | false        | false      | false           | :none                     | :maintainer           | false    # Cluster agent admin but not licensed: not allowed
    false        | false        | true       | false           | :none                     | :developer            | false    # Not a cluster agent admin (must be maintainer): not allowed
    true         | false        | true       | false           | :none                     | :none                 | false    # admin but admin_mode not enabled and licensed: not allowed
    true         | true         | true       | false           | :none                     | :none                 | true     # admin_mode enabled and licensed: allowed
    false        | false        | true       | true            | :developer                | :none                 | true     # Workspace owner and project developer: allowed
    false        | false        | true       | false           | :none                     | :maintainer           | true     # Cluster agent admin: allowed

    # @formatter:on
  end
  # rubocop:enable Layout/LineLength

  with_them do
    # NOTE: Currently :read_workspace and :update_workspace abilities have identical rules, so we can test them with
    #       the same table checks. If their behavior diverges in the future, we'll need to duplicate the table checks.

    describe "read_workspace_variable ability" do
      let(:ability) { :read_workspace_variable }

      it_behaves_like 'fixture sanity checks'

      it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
    end
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  #
  # @param user [User] the user making the request.
  # @param workspace_variable [RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES]
  # the workspace variable that is the subject of the request.
  # @param policy_class [RemoteDevelopment::WorkspaceVariablePolicy] the policy class.
  # @param ability [Symbol] the ability needed by the user to allow the request.
  # @return [nil] This method does not return any value.
  def debug_policies(user, workspace_variable, policy_class, ability)
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}" \
      ")\n"

    policy = policy_class.new(user, workspace_variable)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
