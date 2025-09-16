# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPolicy, feature_category: :groups_and_projects do
  include AdminModeHelper
  include LoginHelpers

  using RSpec::Parameterized::TableSyntax

  def stub_group_saml_config(enabled)
    allow(::Gitlab::Auth::GroupSaml::Config).to receive_messages(enabled?: enabled)
  end

  include_context 'GroupPolicy context'
  # Can't move to GroupPolicy context because auditor trait is not present
  # outside of EE context and FOSS will fail on this
  let_it_be(:auditor) { create(:user, :auditor) }

  let(:epic_rules) do
    %i[read_epic create_epic admin_epic destroy_epic read_confidential_epic
       read_epic_board read_epic_board_list admin_epic_board
       admin_epic_board_list]
  end

  let(:auditor_permissions) do
    %i[
      read_group
      read_group_security_dashboard
      read_cluster
      read_group_runners
      read_billing
      read_container_image
      read_confidential_issues
      read_cycle_analytics
    ]
  end

  context 'when epics feature is disabled' do
    let(:current_user) { owner }

    it { is_expected.to be_disallowed(*epic_rules) }
  end

  context 'when epics feature is enabled' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when user is owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(*epic_rules) }
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(*epic_rules) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(*epic_rules) }
      end
    end

    context 'when user is maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(*(epic_rules - [:destroy_epic])) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(*(epic_rules - [:destroy_epic])) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(*(epic_rules - [:destroy_epic])) }
      it { is_expected.to be_disallowed(:destroy_epic) }
    end

    context 'when user is planner' do
      let(:current_user) { planner }

      it { is_expected.to be_allowed(*epic_rules) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_epic, :read_epic_board, :list_subgroup_epics) }
      it { is_expected.to be_disallowed(*(epic_rules - [:read_epic, :read_epic_board, :read_epic_board_list])) }
    end

    context 'when user is support bot' do
      let_it_be(:current_user) { Users::Internal.support_bot }

      before do
        allow(::ServiceDesk).to receive(:supported?).and_return(true)
      end

      context 'when group has at least one project with service desk enabled' do
        let_it_be(:project_with_service_desk) do
          create(:project, group: group, service_desk_enabled: true)
        end

        it { is_expected.to be_allowed(:read_epic, :read_epic_iid) }
        it { is_expected.to be_disallowed(*(epic_rules - [:read_epic, :read_epic_iid])) }
      end

      context 'when group does not have projects with service desk enabled' do
        let_it_be(:project_without_service_desk) do
          create(:project, group: group, service_desk_enabled: false)
        end

        it { is_expected.to be_disallowed(*epic_rules) }
      end
    end

    context 'when user is not member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(*epic_rules) }
    end

    context 'when user is anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(*epic_rules) }
    end
  end

  context 'when iterations feature is disabled' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(iterations: false)
    end

    it { is_expected.to be_disallowed(:read_iteration, :create_iteration, :admin_iteration, :create_iteration_cadence, :admin_iteration_cadence) }
  end

  context 'when iterations feature is enabled' do
    let(:read_actions) { [:read_iteration, :read_iteration_cadence] }
    let(:edit_actions) { [:create_iteration, :admin_iteration, :create_iteration_cadence, :admin_iteration_cadence] }

    before do
      stub_licensed_features(iterations: true)
    end

    where(:role, :actions, :allowed) do
      :none     | ref(:read_actions) | false
      :none     | ref(:edit_actions) | false
      :guest    | ref(:read_actions) | true
      :guest    | ref(:edit_actions) | false
      :planner  | ref(:read_actions) | true
      :planner  | ref(:edit_actions) | true
      :reporter | ref(:read_actions) | true
      :reporter | ref(:edit_actions) | true
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
    end

    context 'when project is public' do
      let(:group) { create(:group, :public, :owner_subgroup_creation_only) }

      context 'when user is logged out' do
        let(:current_user) { nil }

        it { is_expected.to be_allowed(:read_iteration, :read_iteration_cadence) }
        it { is_expected.to be_disallowed(:create_iteration, :admin_iteration, :create_iteration_cadence, :admin_iteration_cadence) }
      end
    end
  end

  context 'when custom fields are available' do
    before do
      stub_licensed_features(custom_fields: true)
    end

    context 'when user is a guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_custom_field) }
      it { is_expected.to be_disallowed(:admin_custom_field) }
    end

    context 'when user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_custom_field, :admin_custom_field) }
    end

    context 'when user is logged out' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_custom_field) }
    end
  end

  context 'when custom fields are not available' do
    let(:current_user) { guest }

    before do
      stub_licensed_features(custom_fields: false)
    end

    it { is_expected.to be_disallowed(:read_custom_field, :admin_custom_field) }
  end

  context 'when work item statuses are available' do
    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when user is a guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_work_item_lifecycle, :read_work_item_status) }
      it { is_expected.to be_disallowed(:admin_work_item_lifecycle) }
    end

    context 'when user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:read_work_item_lifecycle, :read_work_item_status, :admin_work_item_lifecycle) }
    end

    context 'when user is logged out' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_work_item_lifecycle, :read_work_item_status, :admin_work_item_lifecycle) }
    end
  end

  context 'when work item statuses are not available' do
    let(:current_user) { guest }

    before do
      stub_licensed_features(work_item_status: false)
    end

    it { is_expected.to be_disallowed(:read_work_item_lifecycle, :read_work_item_status, :admin_work_item_lifecycle) }
  end

  context 'when cluster deployments is available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: true)
    end

    it { is_expected.to be_allowed(:read_cluster_environments) }
  end

  context 'when cluster deployments is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: false)
    end

    it { is_expected.not_to be_allowed(:read_cluster_environments) }
  end

  describe 'invite_group_members policy' do
    context 'when on saas', :saas do
      let(:policy) { :invite_group_members }
      let(:app_setting) { :disable_invite_members }

      before do
        stub_saas_features(group_disable_invite_members: true)
      end

      context 'with disable_invite_members is available in license' do
        where(:role, :group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true | false
          :maintainer | true | true | false
          :owner      | false | true | true
          :owner      | false | false | true
          :owner      | true  | true | false
          :owner      | true  | false | false
          :admin      | false | true |  true
          :admin      | false | false | true
          :admin      | false | true | true
          :admin      | false | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: true)
            stub_application_setting(app_setting => application_setting)
            allow(group).to receive(:disable_invite_members?).and_return(group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with disable_invite_members not available in license' do
        where(:role, :group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true |  false
          :maintainer | true | true   | false
          :owner      | false  | true | true
          :owner      | false  | false | true
          :owner      | true   | false | true
          :owner      | true   | true | true
          :admin      | false  | true | true
          :admin      | true | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(app_setting => application_setting)
            allow(group).to receive(:disable_invite_members?).and_return(group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end

    context 'when self-managed' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      let(:app_setting) { :disable_invite_members }
      let(:policy) { :invite_group_members }

      context 'with disable_invite_members available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | false
          :maintainer | true  | nil    | false
          :owner      | false | nil    | true
          :owner      | true  | nil    | false
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: true)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with disable_invite_members not available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | false
          :maintainer | true  | nil    | false
          :owner      | false | nil    | true
          :owner      | true  | nil    | true
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
          :admin      | true  | true   | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end
  end

  describe 'modify_value_stream_dashboard_settings policy' do
    context 'when analytics dashboard is available' do
      let(:current_user) { maintainer }

      before do
        stub_licensed_features(group_level_analytics_dashboard: true)
      end

      it { is_expected.to be_allowed(:modify_value_stream_dashboard_settings) }

      context 'when the current user is the owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when the current user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when a sub-group is given' do
        let(:sub_group) { create(:group, :private, parent: group) }

        subject { described_class.new(maintainer, sub_group) }

        it { is_expected.not_to be_allowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when the user is not a maintainer' do
        let(:current_user) { developer }

        it { is_expected.not_to be_allowed(:modify_value_stream_dashboard_settings) }
      end
    end

    context 'when analytics dashboard is not available' do
      let(:current_user) { maintainer }

      before do
        stub_licensed_features(group_level_analytics_dashboard: false)
      end

      it { is_expected.not_to be_allowed(:modify_value_stream_dashboard_settings) }
    end
  end

  context 'when contribution analytics is available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: true)
    end

    context 'when signed in user is a member of the group' do
      it { is_expected.to be_allowed(:read_group_contribution_analytics) }
    end

    describe 'when user is not a member of the group' do
      let(:current_user) { non_group_member }
      let(:private_group) { create(:group, :private) }

      subject { described_class.new(non_group_member, private_group) }

      context 'when user is not invited to any of the group projects' do
        it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
      end

      context 'when user is invited to a group project, but not to the group' do
        let(:private_project) { create(:project, :private, group: private_group) }

        before do
          private_project.add_guest(non_group_member)
        end

        it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
      end

      context 'when user has an auditor role' do
        before do
          allow(current_user).to receive(:auditor?).and_return(true)
        end

        it { is_expected.to be_allowed(:read_group_contribution_analytics) }
      end
    end
  end

  context 'when contribution analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_contribution_analytics) }
  end

  context 'when dora4 analytics is available' do
    before do
      stub_licensed_features(dora4_analytics: true)
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_dora4_analytics) }
    end

    context 'when the user is an auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_dora4_analytics) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_dora4_analytics) }
    end
  end

  context 'when dora4 analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(dora4_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_dora4_analytics) }
  end

  describe ':read_product_analytics', :enable_admin_mode do
    where(:role, :allowed) do
      :guest     | false
      :planner   | false
      :reporter  | true
      :developer | true
      :admin     | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      it { is_expected.to(allowed ? be_allowed(:read_product_analytics) : be_disallowed(:read_product_analytics)) }
    end
  end

  describe ':read_enterprise_ai_analytics' do
    context 'when on SAAS', :saas do
      let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

      it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
    end

    context 'when on self-managed' do
      let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

      it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
    end

    context 'when Amazon Q is enabled' do
      using RSpec::Parameterized::TableSyntax

      where(:role, :amazon_q_enabled, :allow_policy) do
        :guest    | true  | be_disallowed(:read_enterprise_ai_analytics)
        :reporter | true  | be_allowed(:read_enterprise_ai_analytics)
        :reporter | false | be_disallowed(:read_enterprise_ai_analytics)
        :reporter | true  | be_allowed(:read_pro_ai_analytics)
        :reporter | false | be_disallowed(:read_pro_ai_analytics)
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
        end

        it { is_expected.to allow_policy }
      end
    end
  end

  describe ':read_pro_ai_analytics' do
    context 'when on SAAS', :saas do
      context 'with pro subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

        it_behaves_like 'ai permission to', :read_pro_ai_analytics
      end

      context 'with enterprise subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

        it_behaves_like 'ai permission to', :read_pro_ai_analytics
      end
    end

    context 'when on self-managed' do
      context 'with pro subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

        it_behaves_like 'ai permission to', :read_pro_ai_analytics
      end

      context 'with enterprise subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

        it_behaves_like 'ai permission to', :read_pro_ai_analytics
      end
    end
  end

  describe ':read_duo_usage_analytics' do
    context 'when on SAAS', :saas do
      context 'with core subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with pro subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with enterprise subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with amazon q subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q, namespace: group) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end
    end

    context 'when on self-managed' do
      context 'with self-hosted subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_self_hosted, :self_managed) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with core subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with pro subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with enterprise subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end

      context 'with amazon q subscription' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q, :self_managed) }

        it_behaves_like 'read_duo_usage_analytics permissions'
      end
    end
  end

  describe 'analytics value streams' do
    context 'when feature is not available' do
      context 'and user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.not_to be_allowed(:admin_value_stream) }
      end

      context 'and user is reporter' do
        let(:current_user) { reporter }

        it { is_expected.not_to be_allowed(:admin_value_stream) }
      end
    end

    context 'when user feature is available' do
      before do
        stub_licensed_features(cycle_analytics_for_groups: true)
      end

      context 'and user is guest' do
        let(:current_user) { guest }

        it { is_expected.not_to be_allowed(:admin_value_stream) }
      end

      context 'and user is reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_allowed(:admin_value_stream) }
      end

      context 'and user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:admin_value_stream) }
      end
    end
  end

  context 'export group memberships' do
    let(:current_user) { owner }

    context 'when exporting user permissions is not available' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      it { is_expected.not_to be_allowed(:export_group_memberships) }
    end

    context 'when exporting user permissions is available' do
      before do
        stub_licensed_features(export_user_permissions: true)
      end

      it { is_expected.to be_allowed(:export_group_memberships) }
    end
  end

  context 'when group activity analytics is available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(group_activity_analytics: true)
    end

    it { is_expected.to be_allowed(:read_group_activity_analytics) }
  end

  context 'when group activity analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(group_activity_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_activity_analytics) }
  end

  context 'group CI/CD analytics' do
    context 'when group CI/CD analytics is available' do
      before do
        stub_licensed_features(group_ci_cd_analytics: true)
      end

      context 'when the user has at least reporter permissions' do
        let(:current_user) { reporter }

        it { is_expected.to be_allowed(:view_group_ci_cd_analytics) }
      end

      context 'when the user has less than reporter permissions' do
        let(:current_user) { guest }

        it { is_expected.not_to be_allowed(:view_group_ci_cd_analytics) }
      end

      context 'when the user has auditor permissions' do
        let(:current_user) { auditor }

        it { is_expected.to be_allowed(:view_group_ci_cd_analytics) }
      end
    end

    context 'when group CI/CD analytics is not available' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(group_ci_cd_analytics: false)
      end

      it { is_expected.not_to be_allowed(:view_group_ci_cd_analytics) }
    end
  end

  context 'when group repository analytics is available' do
    before do
      stub_licensed_features(group_repository_analytics: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:read_group_repository_analytics) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_group_repository_analytics) }
    end

    context 'for auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_group_repository_analytics) }
    end
  end

  context 'when group repository analytics is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(group_repository_analytics: false)
    end

    it { is_expected.not_to be_allowed(:read_group_repository_analytics) }
  end

  context 'when group cycle analytics is available' do
    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:read_cycle_analytics) }
      it { is_expected.not_to be_allowed(:read_group_stage) }
      it { is_expected.not_to be_allowed(:view_type_of_work_charts) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_cycle_analytics) }
      it { is_expected.to be_allowed(:read_group_stage) }
      it { is_expected.to be_allowed(:view_type_of_work_charts) }
    end

    context 'for auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_cycle_analytics) }
      it { is_expected.to be_allowed(:read_group_stage) }
      it { is_expected.to be_allowed(:view_type_of_work_charts) }
    end
  end

  context 'when group cycle analytics is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cycle_analytics_for_groups: false)
    end

    it { is_expected.not_to be_allowed(:read_cycle_analytics) }
  end

  context 'when group coverage reports is available' do
    before do
      stub_licensed_features(group_coverage_reports: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { is_expected.not_to be_allowed(:read_group_coverage_reports) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { is_expected.to be_allowed(:read_group_coverage_reports) }
    end
  end

  context 'when group coverage reports is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(group_coverage_reports: false)
    end

    it { is_expected.not_to be_allowed(:read_group_coverage_reports) }
  end

  describe 'per group SAML' do
    context 'when group_saml is unavailable' do
      let(:current_user) { owner }

      context 'when group saml config is disabled' do
        before do
          stub_group_saml_config(false)
        end

        it { is_expected.to be_disallowed(:admin_group_saml) }
      end

      context 'when the group is a subgroup' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }

        before do
          stub_group_saml_config(true)
        end

        subject { described_class.new(current_user, subgroup) }

        it { is_expected.to be_disallowed(:admin_group_saml) }
      end

      context 'when the feature is not licensed' do
        before do
          stub_group_saml_config(true)
          stub_licensed_features(group_saml: false)
        end

        it { is_expected.to be_disallowed(:admin_group_saml) }
      end
    end

    context 'when group_saml is available' do
      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when group_saml_group_sync is not licensed' do
        context 'with an enabled SAML provider' do
          let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

          context 'owner' do
            let(:current_user) { owner }

            it { is_expected.to be_disallowed(:admin_saml_group_links) }
          end

          context 'admin' do
            let(:current_user) { admin }

            it 'is disallowed even with admin mode', :enable_admin_mode do
              is_expected.to be_disallowed(:admin_saml_group_links)
            end
          end
        end
      end

      context 'when group_saml_group_sync is licensed', :saas do
        before do
          stub_group_saml_config(true)
          stub_application_setting(check_namespace_plan: true)
        end

        before_all do
          create(:license, plan: License::ULTIMATE_PLAN)
          create(:gitlab_subscription, :premium, namespace: group)
        end

        context 'without an enabled SAML provider' do
          context 'maintainer' do
            let(:current_user) { maintainer }

            it { is_expected.to be_disallowed(:admin_group_saml) }
            it { is_expected.to be_disallowed(:admin_saml_group_links) }
          end

          context 'owner' do
            let(:current_user) { owner }

            it { is_expected.to be_allowed(:admin_group_saml) }
            it { is_expected.to be_disallowed(:admin_saml_group_links) }
          end

          context 'admin' do
            let(:current_user) { admin }

            context 'when admin mode is enabled', :enable_admin_mode do
              it { is_expected.to be_allowed(:admin_group_saml) }
              it { is_expected.to be_disallowed(:admin_saml_group_links) }
            end

            context 'when admin mode is disabled' do
              it { is_expected.to be_disallowed(:admin_group_saml) }
              it { is_expected.to be_disallowed(:admin_saml_group_links) }
            end
          end
        end

        context 'with an enabled SAML provider' do
          let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

          context 'maintainer' do
            let(:current_user) { maintainer }

            it { is_expected.to be_disallowed(:admin_saml_group_links) }
          end

          context 'owner' do
            let(:current_user) { owner }

            it { is_expected.to be_allowed(:admin_saml_group_links) }
          end

          context 'admin' do
            let(:current_user) { admin }

            context 'when admin mode is enabled', :enable_admin_mode do
              it { is_expected.to be_allowed(:admin_saml_group_links) }
            end

            context 'when admin mode is disabled' do
              it { is_expected.to be_disallowed(:admin_saml_group_links) }
            end
          end

          context 'when the group is a subgroup' do
            let_it_be(:subgroup) { create(:group, :private, parent: group) }

            let(:current_user) { owner }

            subject { described_class.new(current_user, subgroup) }

            it { is_expected.to be_allowed(:admin_saml_group_links) }
          end
        end
      end

      context 'with SSO enforcement enabled' do
        let(:current_user) { guest }

        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }

        context 'when in context of the user web activity' do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[current_user.id], current_user.authenticatable_salt]

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          it 'prevents access without a SAML session' do
            is_expected.not_to be_allowed(:read_group)
          end

          it 'allows access with a SAML session' do
            Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session

            is_expected.to be_allowed(:read_group)
          end
        end

        context 'when there is no global session or sso state' do
          it "allows access because we haven't yet restricted all use cases" do
            is_expected.to be_allowed(:read_group)
          end

          context 'when the current user is a deploy token' do
            let(:current_user) { create(:deploy_token, :group, groups: [group], read_package_registry: true) }

            it 'allows access without a SAML session' do
              is_expected.to allow_action(:read_group)
            end
          end
        end
      end

      context 'without SSO enforcement enabled' do
        let(:current_user) { guest }

        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: false) }

        context 'when in context of the user web activity' do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[current_user.id], current_user.authenticatable_salt]

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          it 'allows access when the user has no Group SAML identity' do
            is_expected.to be_allowed(:read_group)
          end
        end

        context 'when there is no global session or sso state' do
          context 'when the current user is a deploy token' do
            let(:current_user) { create(:deploy_token, :group, groups: [group], read_package_registry: true) }

            it 'allows access without a SAML session' do
              is_expected.to allow_action(:read_group)
            end
          end
        end
      end
    end

    context 'reading a group' do
      context 'when SAML SSO is enabled for resource' do
        let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: false) }
        let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
        let(:root_group) { saml_provider.group }
        let(:subgroup) { create(:group, parent: root_group) }
        let(:member_with_identity) { identity.user }
        let(:member_without_identity) { create(:user) }
        let(:non_member) { create(:user) }
        let(:not_signed_in_user) { nil }

        before do
          stub_licensed_features(group_saml: true)
          root_group.add_developer(member_with_identity)
          root_group.add_developer(member_without_identity)
        end

        subject { described_class.new(current_user, resource) }

        shared_examples 'does not allow read group' do
          it 'does not allow read group' do
            is_expected.not_to allow_action(:read_group)
          end
        end

        shared_examples 'allows to read group' do
          it 'allows read group' do
            is_expected.to allow_action(:read_group)
          end
        end

        shared_examples 'does not allow to read group due to its visibility level' do
          it 'does not allow to read group due to its visibility level', :aggregate_failures do
            expect(resource.root_ancestor.saml_provider.enforced_sso?).to eq(false)

            is_expected.not_to allow_action(:read_group)
          end
        end

        # See https://docs.gitlab.com/ee/user/group/saml_sso/#sso-enforcement
        where(:resource, :resource_visibility_level, :enforced_sso?, :user, :user_is_resource_owner?, :user_with_saml_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
          # Project/Group visibility: Private; Enforce SSO setting: Off

          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'

          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read group due to its visibility level'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'

          # Project/Group visibility: Private; Enforce SSO setting: On

          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'

          # Project/Group visibility: Public; Enforce SSO setting: Off

          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'

          ref(:root_group) | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'

          # Project/Group visibility: Public; Enforce SSO setting: On

          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
        end

        with_them do
          context "when 'Enforce SSO-only authentication for web activity for this group' option is #{params[:enforced_sso?] ? 'enabled' : 'not enabled'}" do
            around do |example|
              session = {}

              session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

              Gitlab::Session.with_session(session) do
                example.run
              end
            end

            before do
              saml_provider.update!(enforced_sso: enforced_sso?)
            end

            context "when resource is #{params[:resource_visibility_level]}" do
              before do
                resource.update!(visibility_level: Gitlab::VisibilityLevel.string_options[resource_visibility_level])
              end

              context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
                before do
                  if user_is_resource_owner?
                    resource.root_ancestor.member(user).update_column(:access_level, Gitlab::Access::OWNER)
                  end

                  Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session if user_with_saml_session?

                  user.update!(admin: true) if user_is_admin?
                  user.update!(auditor: true) if user_is_auditor?
                end

                let(:current_user) { user }

                include_examples params[:shared_examples]
              end
            end
          end
        end
      end
    end
  end

  describe 'admin_saml_group_links for global SAML' do
    let(:current_user) { owner }

    it { is_expected.to be_disallowed(:admin_saml_group_links) }

    context 'when global SAML is enabled' do
      context 'when the groups attribute is not configured' do
        before do
          stub_basic_saml_config
        end

        it { is_expected.to be_disallowed(:admin_saml_group_links) }
      end

      context 'when the groups attribute is configured' do
        before do
          stub_omniauth_config(providers: [{ name: 'saml', groups_attribute: 'Groups', args: {} }])
        end

        it { is_expected.to be_disallowed(:admin_saml_group_links) }

        context 'when saml_group_sync feature is licensed' do
          before do
            stub_licensed_features(saml_group_sync: true)
          end

          it { is_expected.to be_allowed(:admin_saml_group_links) }

          context 'when the current user is not an admin or owner' do
            let(:current_user) { maintainer }

            it { is_expected.to be_disallowed(:admin_saml_group_links) }
          end
        end
      end
    end
  end

  context 'with ip restriction' do
    let(:current_user) { maintainer }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
      stub_licensed_features(group_ip_restriction: true, epics: true)
      stub_config(dependency_proxy: { enabled: true })
    end

    context 'without restriction' do
      it { is_expected.to be_allowed(:read_group) }
      it { is_expected.to be_allowed(:read_milestone) }
      it { is_expected.to be_allowed(:read_package) }
      it { is_expected.to be_allowed(:create_package) }
      it { is_expected.to be_allowed(:destroy_package) }
      it { is_expected.to be_allowed(:create_epic) }
      it { is_expected.to be_allowed(:read_dependency_proxy) }
      it { is_expected.to be_disallowed(:admin_package) }
      it { is_expected.to be_disallowed(:admin_dependency_proxy) }
    end

    context 'with restriction' do
      before do
        create(:ip_restriction, group: group, range: range)
      end

      context 'address is within the range' do
        let(:range) { '192.168.0.0/24' }

        it { is_expected.to be_allowed(:read_group) }
        it { is_expected.to be_allowed(:read_milestone) }
        it { is_expected.to be_allowed(:read_package) }
        it { is_expected.to be_allowed(:create_package) }
        it { is_expected.to be_allowed(:destroy_package) }
        it { is_expected.to be_allowed(:create_epic) }
        it { is_expected.to be_allowed(:read_dependency_proxy) }
        it { is_expected.to be_disallowed(:admin_package) }
        it { is_expected.to be_disallowed(:admin_dependency_proxy) }
      end

      context 'address is outside the range' do
        let(:range) { '10.0.0.0/8' }

        context 'as maintainer' do
          it { is_expected.to be_disallowed(:read_group) }
          it { is_expected.to be_disallowed(:read_milestone) }
          it { is_expected.to be_disallowed(:read_package) }
          it { is_expected.to be_disallowed(:create_package) }
          it { is_expected.to be_disallowed(:destroy_package) }
          it { is_expected.to be_disallowed(:create_epic) }
          it { is_expected.to be_disallowed(:admin_package) }
          it { is_expected.to be_disallowed(:read_dependency_proxy) }
          it { is_expected.to be_disallowed(:admin_dependency_proxy) }
        end

        context 'as owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:read_group) }
          it { is_expected.to be_allowed(:read_milestone) }
          it { is_expected.to be_allowed(:read_package) }
          it { is_expected.to be_allowed(:create_package) }
          it { is_expected.to be_allowed(:destroy_package) }
          it { is_expected.to be_allowed(:admin_package) }
          it { is_expected.to be_allowed(:read_dependency_proxy) }
          it { is_expected.to be_allowed(:admin_dependency_proxy) }
        end

        context 'as auditor' do
          let(:current_user) { create(:user, :auditor) }

          it { is_expected.to be_allowed(:read_group) }
          it { is_expected.to be_allowed(:read_milestone) }
          it { is_expected.to be_allowed(:read_group_audit_events) }
          it { is_expected.to be_allowed(:read_dependency_proxy) }
          it { is_expected.to be_disallowed(:admin_dependency_proxy) }
        end
      end
    end
  end

  context 'when LDAP sync is not enabled' do
    context 'owner' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_allowed(:admin_ldap_group_links) }

      context 'does not allow group owners to manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_disallowed(:override_group_member) }
        it { is_expected.to be_allowed(:admin_ldap_group_links) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:override_group_member) }
        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      end
    end
  end

  context 'when memberships locked to SAML' do
    let(:saml_with_group_sync) do
      {
        name: 'saml',
        groups_attribute: 'groups',
        external_groups: [],
        args: {}
      }
    end

    before do
      stub_application_setting(lock_memberships_to_saml: true)
      stub_licensed_features(saml_group_sync: true)
    end

    context 'when group is a root group' do
      before do
        stub_omniauth_config(providers: [saml_with_group_sync])
        allow(Devise).to receive(:omniauth_providers).and_return([:saml])
      end

      context 'when SAML group link sync is enabled' do
        before do
          create(:saml_group_link, group: group)
        end

        context 'admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.not_to be_allowed(:admin_group_member) }
          end
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end
      end

      context 'when no SAML sync is enabled' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'admin' do
          let(:current_user) { admin }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:admin_group_member) }
        end
      end
    end

    context 'when group is not a root group' do
      let(:parent_group) { create(:group) }
      let(:group) { create(:group, :private, parent: parent_group) }

      before do
        stub_omniauth_config(providers: [saml_with_group_sync])
        allow(Devise).to receive(:omniauth_providers).and_return([:saml])

        group.add_owner(owner)
        parent_group.add_owner(owner)
      end

      context 'when SAML group link sync is enabled' do
        before do
          create(:saml_group_link, group: parent_group)
        end

        context 'admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.not_to be_allowed(:admin_group_member) }
          end
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'when child group has different owner than parent group' do
          let(:sub_group_owner) { create(:user) }
          let(:current_user) { sub_group_owner }

          before do
            group.add_owner(sub_group_owner)
          end

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end
      end

      context 'when no SAML group link sync is enabled' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'admin' do
          let(:current_user) { admin }

          it { is_expected.to be_disallowed(:admin_group_member) }
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:admin_group_member) }
        end

        context 'maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.to be_disallowed(:admin_group_member) }
        end
      end
    end

    context 'when group is synced via GroupSaml', :saas do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
        stub_group_saml_config(true)
        create(:saml_provider, group: group.root_ancestor, enabled: true)
      end

      context 'when SAML group link is configured' do
        before do
          create(:saml_group_link, group: group)
        end

        context 'admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.not_to be_allowed(:admin_group_member) }
          end
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'maintainer' do
          let(:current_user) { maintainer }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end
      end

      context 'when SAML group link is not configured' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'admin' do
          let(:current_user) { admin }

          it { is_expected.not_to be_allowed(:admin_group_member) }
        end

        context 'owner' do
          let(:current_user) { owner }

          it { is_expected.to be_allowed(:admin_group_member) }
        end
      end
    end
  end

  context 'when LDAP sync is enabled' do
    before do
      allow(group).to receive(:ldap_synced?).and_return(true)
    end

    context 'with no user' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'guests' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'planners' do
      let(:current_user) { planner }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:override_group_member) }
      it { is_expected.to be_disallowed(:admin_ldap_group_links) }
    end

    context 'owner' do
      let(:current_user) { owner }

      context 'allow group owners to manage ldap' do
        it { is_expected.to be_allowed(:override_group_member) }
      end

      context 'does not allow group owners to manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { is_expected.to be_disallowed(:override_group_member) }
        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:override_group_member) }
        it { is_expected.to be_allowed(:admin_ldap_group_links) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:override_group_member) }
        it { is_expected.to be_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'when memberships locked to LDAP' do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: true)
        stub_application_setting(lock_memberships_to_ldap: true)
      end

      context 'admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:override_group_member) }
          it { is_expected.to be_allowed(:update_group_member) }
        end

        context 'when admin mode disabled' do
          it { is_expected.to be_disallowed(:override_group_member) }
          it { is_expected.to be_disallowed(:update_group_member) }
        end
      end

      context 'owner' do
        let(:current_user) { owner }

        it { is_expected.not_to be_allowed(:admin_group_member) }
        it { is_expected.not_to be_allowed(:override_group_member) }
        it { is_expected.not_to be_allowed(:update_group_member) }

        context 'and service_accounts feature is enabled' do
          before do
            stub_licensed_features(service_accounts: true)
          end

          it { is_expected.to be_allowed(:admin_service_account_member) }
        end
      end
    end
  end

  describe 'read_group_credentials_inventory' do
    using RSpec::Parameterized::TableSyntax

    let(:non_member) { create(:user) }
    let_it_be(:read_policy) { :read_group_credentials_inventory }
    let_it_be(:admin_policy) { :admin_group_credentials_inventory }

    where(:user, :admin_mode?, :saas?, :licensed?, :allowed) do
      ref(:admin)      | false | false | false | false
      ref(:admin)      | true  | false | false | false
      ref(:admin)      | true  | true  | false | false
      ref(:admin)      | false | false | true  | false
      ref(:admin)      | false | true  | true  | false
      ref(:admin)      | true  | false | true  | false
      ref(:admin)      | false | true  | false | false
      ref(:admin)      | true  | true  | true  | true

      ref(:owner)      | nil   | false | false | false
      ref(:owner)      | nil   | true  | false | false
      ref(:owner)      | nil   | false | true  | false
      ref(:owner)      | nil   | true  | false | false
      ref(:owner)      | nil   | true  | true  | true

      ref(:maintainer) | nil   | true  | true  | false
      ref(:developer)  | nil   | true  | true  | false
      ref(:reporter)   | nil   | true  | true  | false
      ref(:guest)      | nil   | true  | true  | false
      ref(:non_member) | nil   | true  | true  | false
      nil              | nil   | true  | true  | false
    end

    with_them do
      let(:current_user) { user }

      before do
        stub_licensed_features(credentials_inventory: licensed?)
      end

      context 'for user', saas: params[:saas?], enable_admin_mode: params[:admin_mode?] do
        it { is_expected.to(allowed ? be_allowed(read_policy) : be_disallowed(read_policy)) }
        it { is_expected.to(allowed ? be_allowed(admin_policy) : be_disallowed(admin_policy)) }
      end
    end

    context 'subgroup', :saas do
      let(:current_user) { owner }
      let(:subgroup) { create(:group, :private, parent: group) }

      subject { described_class.new(current_user, subgroup) }

      before do
        stub_licensed_features(credentials_inventory: true)
      end

      it { is_expected.to be_disallowed(read_policy) }
      it { is_expected.to be_disallowed(admin_policy) }
    end
  end

  describe 'change_prevent_group_forking' do
    context 'when feature is disabled' do
      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end
    end

    context 'when feature is enabled' do
      before do
        stub_licensed_features(group_forking_protection: true)
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:change_prevent_group_forking) }

        context 'when group has parent' do
          let(:group) { create(:group, :private, parent: create(:group)) }

          it { is_expected.to be_disallowed(:change_prevent_group_forking) }
        end
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:change_prevent_group_forking) }
      end
    end
  end

  describe 'security orchestration policies' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'with developer or maintainer role' do
      where(role: %w[maintainer developer])

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:read_security_orchestration_policies) }
      end
    end

    context 'with owner role' do
      where(role: %w[owner])

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:read_security_orchestration_policies) }
      end
    end

    context 'with auditor role' do
      where(role: %w[auditor])

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_allowed(:read_security_orchestration_policies) }
      end
    end
  end

  describe "security dashboard policies" do
    where(:policy, :role, :admin_mode, :allowed) do
      :admin_vulnerability           | :admin      | false | false
      :admin_vulnerability           | :admin      | true  | true
      :admin_vulnerability           | :auditor    | nil   | false
      :admin_vulnerability           | :developer  | nil   | false
      :admin_vulnerability           | :guest      | nil   | false
      :admin_vulnerability           | :planner    | nil   | false
      :admin_vulnerability           | :maintainer | nil   | true
      :admin_vulnerability           | :owner      | nil   | true
      :admin_vulnerability           | :reporter   | nil   | false
      :read_dependency               | :admin      | false | false
      :read_dependency               | :admin      | true  | true
      :read_dependency               | :auditor    | nil   | true
      :read_dependency               | :developer  | nil   | true
      :read_dependency               | :guest      | nil   | false
      :read_dependency               | :planner    | nil   | false
      :read_dependency               | :maintainer | nil   | true
      :read_dependency               | :owner      | nil   | true
      :read_dependency               | :reporter   | nil   | false
      :read_group_security_dashboard | :admin      | false | false
      :read_group_security_dashboard | :admin      | true  | true
      :read_group_security_dashboard | :auditor    | nil   | true
      :read_group_security_dashboard | :developer  | nil   | true
      :read_group_security_dashboard | :guest      | nil   | false
      :read_group_security_dashboard | :planner    | nil   | false
      :read_group_security_dashboard | :maintainer | nil   | true
      :read_group_security_dashboard | :owner      | nil   | true
      :read_group_security_dashboard | :reporter   | nil   | false
      :read_licenses                 | :admin      | false | false
      :read_licenses                 | :admin      | true  | true
      :read_licenses                 | :auditor    | nil   | true
      :read_licenses                 | :developer  | nil   | true
      :read_licenses                 | :guest      | nil   | false
      :read_licenses                 | :planner    | nil   | false
      :read_licenses                 | :maintainer | nil   | true
      :read_licenses                 | :owner      | nil   | true
      :read_licenses                 | :reporter   | nil   | false
      :read_vulnerability            | :admin      | false | false
      :read_vulnerability            | :admin      | true  | true
      :read_vulnerability            | :auditor    | nil   | true
      :read_vulnerability            | :developer  | nil   | true
      :read_vulnerability            | :guest      | nil   | false
      :read_vulnerability            | :planner    | nil   | false
      :read_vulnerability            | :maintainer | nil   | true
      :read_vulnerability            | :owner      | nil   | true
      :read_vulnerability            | :reporter   | nil   | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      context "with security_dashboard enabled" do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end

      context "with security_dashboard disabled" do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { is_expected.to be_disallowed(policy) }
      end
    end
  end

  describe ':read_vulnerability_statistics' do
    let(:policy) { :read_vulnerability_statistics }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | true
      :maintainer | nil   | true
      :owner      | nil   | true
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'resolve_vulnerability_with_ai' do
    before do
      stub_licensed_features(
        security_dashboard: true,
        ai_features: true
      )
      allow(current_user).to receive(:allowed_to_use?).and_return(true)
    end

    context 'when user cannot :read_security_resource' do
      let(:current_user) { guest }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_disallowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        end

        it { is_expected.to cs_matcher }
      end
    end

    context 'when user can?(:read_security_resource)' do
      let(:current_user) { developer }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_allowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        end

        it { is_expected.to cs_matcher }
      end
    end
  end

  describe 'admin_vulnerability' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:admin_vulnerability) }
    end

    context 'with auditor' do
      let(:current_user) { auditor }

      context "when auditor is not a group member" do
        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context "when developer doesn't have developer-level access to a group" do
        before do
          group.add_reporter(auditor)
        end

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end

      context 'when auditor has developer-level access to a group' do
        before do
          group.add_developer(auditor)
        end

        it { is_expected.to be_disallowed(:admin_vulnerability) }
      end
    end
  end

  describe 'read_group_security_dashboard & create_vulnerability_export' do
    let(:abilities) do
      %i[read_group_security_dashboard create_vulnerability_export read_security_resource read_dependency read_licenses]
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(*abilities) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(*abilities) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(*abilities) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(*abilities) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(*abilities) }

      context 'when security dashboard features is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { is_expected.to be_disallowed(*abilities) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with planner' do
      let(:current_user) { planner }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with non member' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_disallowed(*abilities) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(*abilities) }
    end
  end

  describe 'private nested group use the highest access level from the group and inherited permissions' do
    let(:nested_group) { create(:group, :private, parent: group) }

    before do
      nested_group.add_guest(guest)
      nested_group.add_guest(reporter)
      nested_group.add_guest(developer)
      nested_group.add_guest(maintainer)

      group.members.all_owners.destroy_all # rubocop: disable Cop/DestroyAll

      group.add_guest(owner)
      nested_group.add_owner(owner)
    end

    subject { described_class.new(current_user, nested_group) }

    context 'auditor' do
      let(:current_user) { create(:user, :auditor) }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      specify do
        expect_allowed(*auditor_permissions)
        expect_disallowed(*(reporter_permissions - auditor_permissions))
        expect_disallowed(*(developer_permissions - auditor_permissions))
        expect_disallowed(*(maintainer_permissions - auditor_permissions))
        expect_disallowed(*(owner_permissions - auditor_permissions))
      end
    end
  end

  context 'when push_rules is not enabled by the current license' do
    before do
      stub_licensed_features(push_rules: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:change_push_rules) }
  end

  context 'when push_rules is enabled by the current license' do
    before do
      stub_licensed_features(push_rules: true)
    end

    let(:current_user) { maintainer }

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_push_rules) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_push_rules) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:change_push_rules) }
    end
  end

  context 'when commit_committer_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_commit_committer_check) }
  end

  context 'when commit_committer_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_commit_committer_check) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_commit_committer_check) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_commit_committer_check) }
    end
  end

  context 'when commit_committer_name_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
  end

  context 'when commit_committer_name_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_commit_committer_name_check) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_commit_committer_name_check) }
    end

    context 'the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:change_commit_committer_name_check) }
    end
  end

  context 'when reject_unsigned_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
  end

  context 'when reject_unsigned_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_reject_unsigned_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.not_to be_allowed(:change_reject_unsigned_commits) }
    end
  end

  context 'when reject_non_dco_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: false)
    end

    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
  end

  context 'when reject_non_dco_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { is_expected.to be_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { is_expected.to be_disallowed(:change_reject_non_dco_commits) }
    end
  end

  shared_examples 'analytics policy' do |action|
    shared_examples 'policy by role' do |role|
      context role do
        let(:current_user) { public_send(role) }

        it 'is allowed' do
          is_expected.to be_allowed(action)
        end
      end
    end

    %w[owner maintainer developer reporter].each do |role|
      include_examples 'policy by role', role
    end

    context 'admin' do
      let(:current_user) { admin }

      it 'is allowed when admin mode is enabled', :enable_admin_mode do
        is_expected.to be_allowed(action)
      end

      it 'is not allowed when admin mode is disabled' do
        is_expected.to be_disallowed(action)
      end
    end

    context 'guest' do
      let(:current_user) { guest }

      it 'is not allowed' do
        is_expected.to be_disallowed(action)
      end
    end

    context 'planner' do
      let(:current_user) { planner }

      it 'is not allowed' do
        is_expected.to be_disallowed(action)
      end
    end
  end

  describe 'view_productivity_analytics' do
    include_examples 'analytics policy', :view_productivity_analytics
  end

  describe '#read_group_saml_identity' do
    let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

    context 'for owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_group_saml_identity) }

      context 'without Group SAML enabled' do
        before do
          saml_provider.update!(enabled: false)
        end

        it { is_expected.to be_disallowed(:read_group_saml_identity) }
      end
    end

    %w[maintainer developer reporter guest].each do |role|
      context "for #{role}" do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_disallowed(:read_group_saml_identity) }
      end
    end
  end

  describe 'update_default_branch_protection' do
    context 'for an admin' do
      let(:current_user) { admin }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:update_default_branch_protection) }
          end
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:update_default_branch_protection) }
          end
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:update_default_branch_protection) }
          end
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:update_default_branch_protection) }
          end
        end
      end
    end

    context 'for an owner' do
      let(:current_user) { owner }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_disallowed(:update_default_branch_protection) }
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:update_default_branch_protection) }
        end
      end
    end
  end

  describe ':admin_ci_minutes' do
    let(:policy) { :admin_ci_minutes }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | false
      :maintainer | nil   | false
      :owner      | nil   | true
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':read_group_audit_events' do
    let(:policy) { :read_group_audit_events }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | true
      :maintainer | nil   | true
      :owner      | nil   | true
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  context 'when group is read only' do
    let(:current_user) { owner }
    let(:policies) do
      %i[create_epic update_epic admin_pipeline register_group_runners add_cluster create_cluster
        update_cluster admin_cluster create_deploy_token create_subgroup create_package]
    end

    before do
      allow(group).to receive(:read_only?).and_return(read_only)
      stub_licensed_features(epics: true)
    end

    context 'when the group is read only' do
      let(:read_only) { true }

      it { is_expected.to(be_disallowed(*policies)) }
      it { is_expected.to(be_allowed(:read_billable_member)) }
    end

    context 'when the group is not read only' do
      let(:read_only) { false }

      it { is_expected.to(be_allowed(*policies)) }
    end
  end

  context 'under .com', :saas do
    it_behaves_like 'model with wiki policies' do
      let_it_be_with_refind(:container) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:user) { owner }

      before_all do
        create(:license, plan: License::PREMIUM_PLAN)
      end

      before do
        enable_namespace_license_check!
      end

      def set_access_level(access_level)
        container.group_feature.update_attribute(:wiki_access_level, access_level)
      end

      context 'when the feature is not licensed on this group' do
        let_it_be(:container) { create(:group_with_plan, plan: :bronze_plan) }

        it 'does not include the wiki permissions' do
          expect_disallowed(*wiki_permissions[:all])
        end
      end
    end
  end

  it_behaves_like 'update namespace limit policy'

  context 'group access tokens', :saas do
    context 'GitLab.com Core resource access tokens', :saas do
      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'with owner access' do
        let(:current_user) { owner }

        it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
        it { is_expected.not_to be_allowed(:admin_setting_to_allow_resource_access_token_creation) }
        it { is_expected.to be_allowed(:read_resource_access_tokens) }
        it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
      end
    end

    context 'on GitLab.com paid' do
      let_it_be(:group) { create(:group_with_plan, plan: :bronze_plan) }

      context 'with owner' do
        let(:current_user) { owner }

        before do
          group.add_owner(owner)
        end

        it_behaves_like 'GitLab.com Paid plan resource access tokens'

        context 'create resource access tokens' do
          it { is_expected.to be_allowed(:create_resource_access_tokens) }

          context 'when resource access token creation is not allowed' do
            before do
              group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
            end

            it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
          end

          context 'when parent group has resource access token creation disabled' do
            let(:namespace_settings) { create(:namespace_settings, resource_access_token_creation_allowed: false) }
            let(:parent) { create(:group_with_plan, plan: :bronze_plan, namespace_settings: namespace_settings) }
            let(:group) { create(:group, parent: parent) }

            context 'cannot create resource access tokens' do
              it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
            end

            context 'can render admin settings for resource access token' do
              it { is_expected.to be_allowed(:admin_setting_to_allow_resource_access_token_creation) }
            end
          end
        end

        context 'read resource access tokens' do
          it { is_expected.to be_allowed(:read_resource_access_tokens) }
        end

        context 'destroy resource access tokens' do
          it { is_expected.to be_allowed(:destroy_resource_access_tokens) }
        end

        context 'admin settings `allow resource access token` is allowed' do
          it { is_expected.to be_allowed(:admin_setting_to_allow_resource_access_token_creation) }
        end
      end

      context 'with developer' do
        let(:current_user) { developer }

        before do
          group.add_developer(developer)
        end

        context 'create resource access tokens' do
          it { is_expected.not_to be_allowed(:create_resource_access_tokens) }
        end

        context 'read resource access tokens' do
          it { is_expected.not_to be_allowed(:read_resource_access_tokens) }
        end

        context 'destroy resource access tokens' do
          it { is_expected.not_to be_allowed(:destroy_resource_access_tokens) }
        end
      end
    end
  end

  describe ':read_group_release_stats' do
    shared_examples 'read_group_release_stats permissions' do
      context 'when user is logged out' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(:read_group_release_stats) }
      end

      context 'when user is not a member of the group' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_disallowed(:read_group_release_stats) }
      end

      context 'when user is guest' do
        let(:current_user) { guest }

        it { is_expected.to be_allowed(:read_group_release_stats) }
      end
    end

    context 'when group is private' do
      it_behaves_like 'read_group_release_stats permissions'
    end

    context 'when group is public' do
      let(:group) { create(:group, :public) }

      before do
        group.add_guest(guest)
      end

      it_behaves_like 'read_group_release_stats permissions'
    end

    describe ':admin_merge_request_approval_settings' do
      let(:policy) { :admin_merge_request_approval_settings }

      where(:role, :licensed, :admin_mode, :root_group, :allowed) do
        :guest      | true  | nil   | true  | false
        :guest      | false | nil   | true  | false
        :planner    | true  | nil   | true  | false
        :planner    | false | nil   | true  | false
        :reporter   | true  | nil   | true  | false
        :reporter   | false | nil   | true  | false
        :developer  | true  | nil   | true  | false
        :developer  | false | nil   | true  | false
        :maintainer | true  | nil   | true  | false
        :maintainer | false | nil   | true  | false
        :owner      | true  | nil   | true  | true
        :owner      | true  | nil   | false | false
        :owner      | false | nil   | true  | false
        :admin      | true  | true  | true  | true
        :admin      | true  | true  | false | false
        :admin      | false | true  | true  | false
        :admin      | true  | false | true  | false
        :admin      | false | false | true  | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(merge_request_approvers: licensed)
          enable_admin_mode!(current_user) if admin_mode
          group.parent = build(:group) unless root_group
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'custom roles' do
      let(:license) { :custom_roles }

      context 'when on self-managed' do
        let(:current_user) { owner }

        before do
          stub_licensed_features(license => true)
        end

        it { is_expected.to be_disallowed(:admin_member_role) }
      end

      describe ':admin_member_role', :saas do
        using RSpec::Parameterized::TableSyntax

        where(:role, :allowed) do
          :guest      | false
          :planner    | false
          :reporter   | false
          :developer  | false
          :maintainer | false
          :auditor    | false
          :owner      | true
          :admin      | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            enable_admin_mode!(current_user) if role == :admin
          end

          context 'custom roles license' do
            let(:permissions) { [:admin_member_role, :view_member_roles] }

            context 'when licensed feature is enabled' do
              before do
                stub_licensed_features(license => true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }

              context 'when memberships are locked to LDAP' do
                before do
                  allow(group).to receive(:ldap_synced?).and_return(true)
                  stub_application_setting(allow_group_owners_to_manage_ldap: true)
                  stub_application_setting(lock_memberships_to_ldap: true)
                end

                it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
              end
            end

            context 'when licensed feature is disabled' do
              before do
                stub_licensed_features(license => false)
              end

              it { is_expected.to be_disallowed(*permissions) }
            end
          end

          context 'default roles assignees license' do
            let(:license) { :default_roles_assignees }
            let(:permissions) { [:view_member_roles] }

            context 'when licensed feature is enabled' do
              before do
                stub_licensed_features(license => true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
            end

            context 'when licensed feature is disabled' do
              before do
                stub_licensed_features(license => false)
              end

              it { is_expected.to be_disallowed(*permissions) }
            end
          end
        end
      end

      describe ':read_member_role' do
        using RSpec::Parameterized::TableSyntax

        let(:permissions) { [:read_member_role] }

        where(:role, :allowed) do
          :guest      | true
          :planner    | true
          :reporter   | true
          :developer  | true
          :maintainer | true
          :auditor    | false
          :owner      | true
          :admin      | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            enable_admin_mode!(current_user) if role == :admin
          end

          context 'when custom_roles feature is enabled' do
            before do
              stub_licensed_features(custom_roles: true)
            end

            it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }

            context 'when memberships are locked to LDAP' do
              before do
                allow(group).to receive(:ldap_synced?).and_return(true)
                stub_application_setting(allow_group_owners_to_manage_ldap: true)
                stub_application_setting(lock_memberships_to_ldap: true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
            end
          end

          context 'when custom_roles feature is disabled' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            it { is_expected.to be_disallowed(*permissions) }
          end
        end
      end
    end

    describe ':start_trial' do
      let(:policy) { :start_trial }

      where(:role, :eligible_for_trial, :admin_mode, :allowed) do
        :guest      | true  | nil   | false
        :guest      | false | nil   | false
        :planner    | true  | nil   | false
        :planner    | false | nil   | false
        :reporter   | true  | nil   | false
        :reporter   | false | nil   | false
        :developer  | true  | nil   | false
        :developer  | false | nil   | false
        :maintainer | true  | nil   | true
        :maintainer | false | nil   | false
        :owner      | true  | nil   | true
        :owner      | false | nil   | false
        :admin      | true  | true  | true
        :admin      | false | true  | false
        :admin      | true  | false | false
        :admin      | false | false | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          allow(group).to receive(:eligible_for_trial?).and_return(eligible_for_trial)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'compliance framework permissions' do
    shared_examples 'compliance framework permissions' do
      where(:role, :licensed, :admin_mode, :allowed) do
        :owner      | true  | nil   | true
        :owner      | false | nil   | false
        :admin      | true  | true  | true
        :admin      | true  | false | false
        :maintainer | true  | nil   | false
        :developer  | true  | nil   | false
        :reporter   | true  | nil   | false
        :planner    | true  | nil   | false
        :guest      | true  | nil   | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(licensed_feature => licensed)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context ':admin_compliance_framework' do
      let(:policy) { :admin_compliance_framework }
      let(:licensed_feature) { :custom_compliance_frameworks }
      let(:feature_flag_name) { nil }

      include_examples 'compliance framework permissions'
    end

    context ':admin_compliance_pipeline_configuration' do
      let(:policy) { :admin_compliance_pipeline_configuration }
      let(:licensed_feature) { :evaluate_group_level_compliance_pipeline }

      include_examples 'compliance framework permissions'
    end
  end

  describe 'view_devops_adoption' do
    let(:current_user) { owner }
    let(:policy) { :view_group_devops_adoption }

    context 'when license does not include the feature' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(group_level_devops_adoption: false)
        enable_admin_mode!(current_user)
      end

      it { is_expected.to be_disallowed(policy) }
    end

    context 'when license includes the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | true
        :maintainer       | true
        :developer        | true
        :reporter         | true
        :planner          | false
        :guest            | false
        :non_group_member | false
        :auditor          | true
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'manage_devops_adoption_namespaces' do
    let(:current_user) { owner }
    let(:policy) { :manage_devops_adoption_namespaces }

    context 'when license does not include the feature' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(group_level_devops_adoption: false)
        enable_admin_mode!(current_user)
      end

      it { is_expected.to be_disallowed(policy) }
    end

    context 'when license includes the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | true
        :maintainer       | true
        :developer        | true
        :reporter         | true
        :planner          | false
        :guest            | false
        :non_group_member | false
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'when license plan does not include the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | false
        :maintainer       | false
        :developer        | false
        :reporter         | false
        :planner          | false
        :guest            | false
        :non_group_member | false
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        allow(group).to receive(:feature_available?).with(:group_level_devops_adoption).and_return(false)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  context 'external audit events' do
    let(:current_user) { owner }

    context 'when license is disabled' do
      before do
        stub_licensed_features(external_audit_events: false)
      end

      it { is_expected.to(be_disallowed(:admin_external_audit_events)) }
    end

    context 'when license is enabled' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      it { is_expected.to(be_allowed(:admin_external_audit_events)) }
    end

    context 'when user is not an owner' do
      let(:current_user) { build_stubbed(:user, :auditor) }

      it { is_expected.to(be_disallowed(:admin_external_audit_events)) }
    end
  end

  describe 'a pending membership' do
    let_it_be(:user) { create(:user) }

    context 'with a private group' do
      let_it_be(:private_group) { create(:group, :private) }

      subject { described_class.new(user, private_group) }

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it 'has permission identical to a private group in which the user is not a member' do
          create(:group_member, :awaiting, role, source: private_group, user: user)

          expect_private_group_permissions_as_if_non_member
        end
      end

      context 'with a project in the group' do
        let_it_be(:project) { create(:project, :private, namespace: private_group) }

        where(:role) do
          Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
        end

        with_them do
          it 'has permission identical to a private group in which the user is not a member' do
            create(:group_member, :awaiting, role, source: private_group, user: user)

            expect_private_group_permissions_as_if_non_member
          end
        end
      end
    end

    context 'with a public group' do
      let_it_be(:public_group) { create(:group, :public) }

      subject { described_class.new(user, public_group) }

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it 'has permission identical to a public group in which the user is not a member' do
          create(:group_member, :awaiting, role, source: public_group, user: user)

          expect_allowed(*public_permissions)
          expect_disallowed(:upload_file)
          expect_disallowed(*reporter_permissions)
          expect_disallowed(*developer_permissions)
          expect_disallowed(*maintainer_permissions)
          expect_disallowed(*owner_permissions)
          expect_disallowed(:read_namespace_via_membership)
        end
      end
    end

    context 'with a group invited to another group' do
      let_it_be(:group) { create(:group, :public) }
      let_it_be(:other_group) { create(:group, :private) }

      subject { described_class.new(user, other_group) }

      before_all do
        create(:group_group_link, { shared_with_group: group, shared_group: other_group })
      end

      where(:role) do
        Gitlab::Access.sym_options_with_owner.keys.map(&:to_sym)
      end

      with_them do
        it 'has permission to the other group as if the user is not a member' do
          create(:group_member, :awaiting, role, source: group, user: user)

          expect_private_group_permissions_as_if_non_member
        end
      end
    end

    def expect_private_group_permissions_as_if_non_member
      expect_disallowed(*public_permissions)
      expect_disallowed(*guest_permissions)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  describe 'security complience policy' do
    context 'when licensed feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      context 'with developer or maintainer role' do
        where(role: %w[maintainer developer])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:read_security_orchestration_policies) }
          it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
        end
      end

      context 'with owner role' do
        where(role: %w[owner])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:read_security_orchestration_policies) }
          it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
          it { is_expected.to be_disallowed(:modify_security_policy) }
        end
      end
    end

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when security_orchestration_policy_configuration is not present' do
        context 'with developer or maintainer role' do
          where(role: %w[maintainer developer])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:read_security_orchestration_policies) }
            it { is_expected.to be_disallowed(:update_security_orchestration_policy_project) }
          end
        end

        context 'with owner role' do
          where(role: %w[owner])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(:read_security_orchestration_policies) }
            it { is_expected.to be_allowed(:update_security_orchestration_policy_project) }
            it { is_expected.to be_allowed(:modify_security_policy) }

            context 'when security_orchestration_policy_configuration is present' do
              let_it_be(:security_policy_management_project) { create(:project) }

              before do
                create(:security_orchestration_policy_configuration, project: nil, namespace: group, security_policy_management_project: security_policy_management_project)
              end

              it { is_expected.to be_disallowed(:modify_security_policy) }
            end
          end
        end
      end

      context 'when security_orchestration_policy_configuration is present' do
        let_it_be(:security_policy_management_project) { create(:project) }
        let(:current_user) { developer }

        before do
          create(:security_orchestration_policy_configuration, project: nil, namespace: group, security_policy_management_project: security_policy_management_project)
        end

        context 'when current_user is developer of security_policy_management_project' do
          before do
            security_policy_management_project.add_developer(developer)
          end

          it { is_expected.to be_allowed(:modify_security_policy) }
        end

        context 'when current_user is not developer of security_policy_management_project' do
          it { is_expected.to be_disallowed(:modify_security_policy) }
        end
      end
    end
  end

  describe 'read_usage_quotas policy' do
    context 'reading usage quotas' do
      let(:policy) { :read_usage_quotas }

      where(:role, :admin_mode, :allowed) do
        :owner      | nil   | true
        :admin      | true  | true
        :admin      | false | false
        :maintainer | nil   | false
        :developer  | nil   | false
        :reporter   | nil   | false
        :planner    | nil   | false
        :guest      | nil   | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'dependency proxy' do
    context 'feature enabled' do
      before do
        stub_config(dependency_proxy: { enabled: true })
      end

      context 'auditor' do
        let(:current_user) { auditor }

        it { is_expected.to be_allowed(:read_dependency_proxy) }
        it { is_expected.to be_disallowed(:admin_dependency_proxy) }
      end
    end
  end

  describe 'read wiki' do
    context 'feature enabled' do
      before do
        stub_licensed_features(group_wikis: true)
      end

      context 'auditor' do
        let(:current_user) { auditor }

        it { is_expected.to be_allowed(:read_wiki) }
        it { is_expected.to be_disallowed(:admin_wiki) }
      end
    end

    context 'feature disabled' do
      before do
        stub_licensed_features(group_wikis: false)
      end

      context 'auditor' do
        let(:current_user) { auditor }

        it { is_expected.to be_disallowed(:read_wiki) }
        it { is_expected.to be_disallowed(:admin_wiki) }
      end
    end
  end

  describe 'group level compliance features' do
    shared_examples 'group level compliance feature' do |feature, permission|
      context 'when enabled' do
        before do
          stub_licensed_features({ feature => true })
        end

        context 'when user is eligible for access' do
          where(role: %w[owner auditor])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_allowed(permission) }
          end
        end

        context 'allows admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_allowed(permission) }
        end
      end

      context 'when disabled' do
        before do
          stub_licensed_features({ feature => false })
        end

        context 'when user is eligible for access' do
          where(role: %w[owner auditor])

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(permission) }
          end
        end

        context 'disallows admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.to be_disallowed(permission) }
        end
      end
    end

    describe 'group level compliance dashboard' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_dashboard, :read_compliance_dashboard
    end

    describe 'group level compliance adherence report' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_adherence_report, :read_compliance_adherence_report
    end

    describe 'group level compliance violations report' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_violations_report, :read_compliance_violations_report
    end
  end

  describe 'user banned from namespace' do
    let_it_be_with_reload(:current_user) { create(:user) }
    let_it_be(:group) { create(:group, :private) }

    subject { described_class.new(current_user, group) }

    before do
      stub_licensed_features(unique_project_download_limit: true)
      group.add_developer(current_user)
    end

    context 'when user is not banned' do
      it { is_expected.to be_allowed(:read_group) }
    end

    context 'when user is banned' do
      before do
        create(:namespace_ban, user: current_user, namespace: group.root_ancestor)
      end

      it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }

      context 'inside a subgroup' do
        let_it_be(:group) { create(:group, :private, :nested) }

        it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }

        context 'as an owner of the subgroup' do
          before do
            group.add_owner(current_user)
          end

          it { is_expected.to be_disallowed(*described_class.own_ability_map.map.keys) }
        end
      end

      context 'as an admin' do
        let_it_be(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:read_group) }
        end
      end

      context 'when group is public' do
        let_it_be(:group) { create(:group, :public) }

        it { is_expected.to be_disallowed(:read_group) }
      end

      context 'when licensed feature unique_project_download_limit is not available' do
        before do
          stub_licensed_features(unique_project_download_limit: false)
        end

        it { is_expected.to be_allowed(:read_group) }
      end
    end
  end

  describe 'ban_group_member' do
    let_it_be(:user) { create(:user) }

    let(:group) { create(:group) }

    subject(:policy) { described_class.new(user, group) }

    where(:unique_project_download_limit_enabled, :is_owner, :enabled) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        allow(group).to receive(:unique_project_download_limit_enabled?)
          .and_return(unique_project_download_limit_enabled)
        group.add_owner(user) if is_owner
      end

      it 'has the correct value' do
        if enabled
          expect(policy).to be_allowed(:ban_group_member)
        else
          expect(policy).to be_disallowed(:ban_group_member)
        end
      end
    end
  end

  describe 'group cicd runners' do
    context 'auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_group_runners) }
      it { is_expected.to be_allowed(:read_group_all_available_runners) }
      it { is_expected.to be_disallowed(:register_group_runners) }
      it { is_expected.to be_disallowed(:create_runner) }
    end
  end

  describe 'group container registry' do
    context 'auditor' do
      let(:current_user) { auditor }

      it { is_expected.to be_allowed(:read_container_image) }
      it { is_expected.to be_disallowed(:admin_container_image) }
    end
  end

  describe 'admin_service_accounts' do
    context 'when the feature is not enabled' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:admin_service_accounts) }
      it { is_expected.to be_disallowed(:admin_service_account_member) }
      it { is_expected.to be_disallowed(:create_service_account) }
      it { is_expected.to be_disallowed(:delete_service_account) }
    end

    context 'when feature is enabled' do
      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_disallowed(:admin_service_accounts) }
        it { is_expected.to be_disallowed(:admin_service_account_member) }
        it { is_expected.to be_disallowed(:create_service_account) }
        it { is_expected.to be_disallowed(:delete_service_account) }
      end

      context 'when the user is an owner' do
        let(:current_user) { owner }

        context 'when application setting allow_top_level_group_owners_to_create_service_accounts is disabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
          end

          it { is_expected.to be_allowed(:admin_service_accounts) }
          it { is_expected.to be_allowed(:admin_service_account_member) }
          it { is_expected.to be_disallowed(:create_service_account) }
          it { is_expected.to be_disallowed(:delete_service_account) }

          context 'when saas', :saas do
            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_disallowed(:create_service_account) }
            it { is_expected.to be_disallowed(:delete_service_account) }
          end
        end

        context 'when application setting allow_top_level_group_owners_to_create_service_accounts is enabled ' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          end

          it { is_expected.to be_allowed(:admin_service_accounts) }
          it { is_expected.to be_allowed(:admin_service_account_member) }
          it { is_expected.to be_allowed(:create_service_account) }
          it { is_expected.to be_allowed(:delete_service_account) }

          context 'when saas', :saas do
            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_allowed(:create_service_account) }
            it { is_expected.to be_allowed(:delete_service_account) }

            context 'when trial is active' do
              before do
                allow(group).to receive_messages(trial_active?: true)
              end

              it { is_expected.to be_disallowed(:admin_service_accounts) }
              it { is_expected.to be_disallowed(:admin_service_account_member) }
              it { is_expected.to be_disallowed(:create_service_account) }
              it { is_expected.to be_disallowed(:delete_service_account) }
            end
          end

          context 'when a trial is active' do
            before do
              allow(group).to receive_messages(gitlab_subscription: nil)
            end

            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_allowed(:create_service_account) }
            it { is_expected.to be_allowed(:delete_service_account) }
          end

          context 'for subgroup' do
            let_it_be(:subgroup) { create(:group, :private, parent: group) }

            subject { described_class.new(current_user, subgroup) }

            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_disallowed(:create_service_account) }
            it { is_expected.to be_disallowed(:delete_service_account) }
          end
        end

        context 'for subgroup' do
          let_it_be(:subgroup) { create(:group, :private, parent: group) }

          subject { described_class.new(current_user, subgroup) }

          it { is_expected.to be_allowed(:admin_service_accounts) }
          it { is_expected.to be_allowed(:admin_service_account_member) }
          it { is_expected.to be_disallowed(:create_service_account) }
          it { is_expected.to be_disallowed(:delete_service_account) }

          context 'when a trial is active in GitLab.com', :saas do
            before do
              allow(subgroup.root_ancestor).to receive_messages(trial_active?: true)
            end

            it { is_expected.to be_disallowed(:admin_service_accounts) }
            it { is_expected.to be_disallowed(:admin_service_account_member) }
            it { is_expected.to be_disallowed(:create_service_account) }
            it { is_expected.to be_disallowed(:delete_service_account) }
          end
        end
      end

      context 'when the user is an instance admin' do
        let(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it { is_expected.to be_allowed(:admin_service_accounts) }
          it { is_expected.to be_allowed(:admin_service_account_member) }
          it { is_expected.to be_allowed(:create_service_account) }
          it { is_expected.to be_allowed(:delete_service_account) }

          context 'when a trial is active' do
            before do
              allow(group).to receive_messages(gitlab_subscription: nil)
            end

            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_allowed(:create_service_account) }
            it { is_expected.to be_allowed(:delete_service_account) }
          end

          context 'for subgroup' do
            let_it_be(:subgroup) { create(:group, :private, parent: group) }

            subject { described_class.new(current_user, subgroup) }

            it { is_expected.to be_allowed(:admin_service_accounts) }
            it { is_expected.to be_allowed(:admin_service_account_member) }
            it { is_expected.to be_disallowed(:create_service_account) }
            it { is_expected.to be_disallowed(:delete_service_account) }
          end
        end

        context 'when admin mode is not enabled' do
          it { is_expected.to be_disallowed(:admin_service_accounts) }
          it { is_expected.to be_disallowed(:admin_service_account_member) }
          it { is_expected.to be_disallowed(:create_service_account) }
          it { is_expected.to be_disallowed(:delete_service_account) }
        end
      end
    end
  end

  describe 'access_duo_chat' do
    let_it_be(:current_user) { create(:user) }

    subject { described_class.new(current_user, group) }

    context 'when on SaaS instance', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with duo features enabled and ai chat available for group on SaaS'

        context 'when user is a member of the group' do
          before do
            group.add_guest(current_user)
          end

          it { is_expected.to be_allowed(:access_duo_chat) }

          context 'when the group does not have an Premium SaaS license' do
            let_it_be(:group) { create(:group) }

            it { is_expected.to be_disallowed(:access_duo_chat) }
          end
        end

        context 'when the user is not a member but has AI enabled via another group' do
          context 'user can view group' do
            it 'is allowed' do
              is_expected.to be_allowed(:access_duo_chat)
            end
          end

          context 'user cannot view group' do
            before do
              group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'is not allowed' do
              is_expected.to be_disallowed(:access_duo_chat)
            end
          end
        end
      end
    end

    context 'for self-managed', :with_cloud_connector do
      let_it_be_with_reload(:group) { create(:group) }
      let(:policy) { :access_duo_chat }

      context 'when not on .org or .com' do
        where(:enabled_for_user, :duo_features_enabled, :cs_matcher) do
          true  | false | be_disallowed(policy)
          true  | true  | be_allowed(policy)
          false | false | be_disallowed(policy)
          false | true  | be_disallowed(policy)
        end

        with_them do
          before do
            allow(::Gitlab).to receive(:org_or_com?).and_return(false)
            stub_ee_application_setting(duo_features_enabled: duo_features_enabled, lock_duo_features_enabled: true)
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(current_user, :access_duo_chat).and_return(enabled_for_user)
          end

          it { is_expected.to cs_matcher }
        end
      end
    end
  end

  describe 'access_duo_agentic_chat' do
    let_it_be(:current_user) { create(:user) }

    subject { described_class.new(current_user, group) }

    context 'when on SaaS instance', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with duo features enabled and agentic chat available for group on SaaS'

        context 'when user is a member of the group' do
          before do
            group.add_guest(current_user)
          end

          it { is_expected.to be_allowed(:access_duo_agentic_chat) }

          context 'when the group does not have an Premium SaaS license' do
            let_it_be(:group) { create(:group) }

            it { is_expected.to be_disallowed(:access_duo_agentic_chat) }
          end
        end

        context 'when the user is not a member but has AI enabled via another group' do
          context 'user can view group' do
            it 'is allowed' do
              is_expected.to be_allowed(:access_duo_agentic_chat)
            end
          end

          context 'user cannot view group' do
            before do
              group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'is not allowed' do
              is_expected.to be_disallowed(:access_duo_agentic_chat)
            end
          end
        end
      end
    end

    context 'for self-managed', :with_cloud_connector do
      let_it_be_with_reload(:group) { create(:group) }
      let(:policy) { :access_duo_agentic_chat }

      context 'when not on .org or .com' do
        where(:enabled_for_user, :duo_features_enabled, :cs_matcher) do
          true  | false | be_disallowed(policy)
          true  | true  | be_allowed(policy)
          false | false | be_disallowed(policy)
          false | true  | be_disallowed(policy)
        end

        with_them do
          before do
            allow(::Gitlab).to receive(:org_or_com?).and_return(false)
            stub_ee_application_setting(duo_features_enabled: duo_features_enabled, lock_duo_features_enabled: true)
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(current_user, :access_duo_agentic_chat).and_return(enabled_for_user)
          end

          it { is_expected.to cs_matcher }
        end
      end
    end
  end

  context 'access_duo_features' do
    where(:current_user, :duo_features_enabled, :cs_matcher) do
      ref(:guest) | true | be_allowed(:access_duo_features)
      ref(:guest) | false | be_disallowed(:access_duo_features)
      nil | true | be_disallowed(:access_duo_features)
      nil | false | be_disallowed(:access_duo_features)
    end

    with_them do
      before do
        group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
      end

      it do
        is_expected.to cs_matcher
      end
    end

    context 'when the group is not yet persisted' do
      subject { described_class.new(admin, build(:group)) }

      it { is_expected.to be_disallowed(:access_duo_features) }
    end
  end

  describe 'access to group for duo workflow' do
    let_it_be_with_reload(:group) { create(:group, :public) }

    where(:current_user, :token_info, :duo_features_enabled, :cs_matcher) do
      ref(:guest)      | nil                               | true  | be_allowed(:read_group)
      ref(:guest)      | { token_scopes: [:ai_workflows] } | true  | be_allowed(:read_group)
      ref(:guest)      | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_group, :admin_group)
      ref(:guest)      | { token_scopes: [:other_scope] }  | true  | be_allowed(:read_group)
      ref(:maintainer) | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_group, :admin_group)
    end

    with_them do
      before do
        group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        ::Current.token_info = token_info
      end

      it { is_expected.to cs_matcher }
    end
  end

  describe ':read_saml_user' do
    let_it_be(:user) { non_group_member }
    let_it_be(:subgroup) { create(:group, :private, parent: group) }

    subject(:policy) { described_class.new(user, the_group) }

    context 'when a SAML provider does not exist' do
      let_it_be(:the_group) { subgroup }

      before do
        stub_licensed_features(group_saml: true)
        the_group.add_member(user, Gitlab::Access::OWNER)
      end

      it { is_expected.to be_disallowed(:read_saml_user) }
    end

    context 'when a SAML provider exists' do
      before_all do
        create(:saml_provider, group: group)
      end
      where(:the_group, :licensed, :saml_enabled, :sso_enforced, :role, :allowed) do
        ref(:group)     | false | false | false | Gitlab::Access::OWNER      | false
        ref(:group)     | false | false | false | Gitlab::Access::MAINTAINER | false

        ref(:group)     | true  | false | false | Gitlab::Access::OWNER      | false
        ref(:group)     | true  | false | false | Gitlab::Access::MAINTAINER | false

        ref(:group)     | true  | true  | false | Gitlab::Access::OWNER      | false
        ref(:group)     | true  | true  | false | Gitlab::Access::MAINTAINER | false

        ref(:group)     | true  | true  | true  | Gitlab::Access::OWNER      | true
        ref(:group)     | true  | true  | true  | Gitlab::Access::MAINTAINER | false

        ref(:subgroup)  | false | false | false | Gitlab::Access::OWNER      | false
        ref(:subgroup)  | false | false | false | Gitlab::Access::MAINTAINER | false

        ref(:subgroup)  | true  | false | false | Gitlab::Access::OWNER      | false
        ref(:subgroup)  | true  | false | false | Gitlab::Access::MAINTAINER | false

        ref(:subgroup)  | true  | true  | false | Gitlab::Access::OWNER      | false
        ref(:subgroup)  | true  | true  | false | Gitlab::Access::MAINTAINER | false

        ref(:subgroup)  | true  | true  | true  | Gitlab::Access::OWNER      | true
        ref(:subgroup)  | true  | true  | true  | Gitlab::Access::MAINTAINER | false
      end

      with_them do
        before do
          stub_licensed_features(group_saml: licensed)
          the_group.add_member(user, role)
          the_group.root_ancestor.saml_provider.update!(enabled: saml_enabled)
          the_group.root_ancestor.saml_provider.update!(enforced_sso: sso_enforced)
        end

        it { expect(policy.allowed?(:read_saml_user)).to eq(allowed) }
      end
    end
  end

  context 'custom role' do
    let_it_be(:guest) { create(:user) }
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: parent_group) }

    let_it_be(:parent_group_member_guest) do
      create(
        :group_member,
        user: guest,
        source: parent_group,
        access_level: Gitlab::Access::GUEST
      )
    end

    let_it_be(:group_member_guest) do
      create(
        :group_member,
        user: guest,
        source: group,
        access_level: Gitlab::Access::GUEST
      )
    end

    let(:member_role_abilities) { {} }
    let(:allowed_abilities) { [] }
    let(:disallowed_abilities) { [] }
    let(:licensed_features) { {} }
    let(:current_user) { guest }

    def create_member_role(member, abilities = member_role_abilities)
      params = abilities.merge(namespace: parent_group)

      create(:member_role, :guest, params).tap do |role|
        role.members << member
      end
    end

    shared_examples 'custom roles abilities' do
      subject { described_class.new(current_user, group) }

      context 'without custom_roles license disabled' do
        before do
          create_member_role(group_member_guest)

          stub_licensed_features(licensed_features.merge(custom_roles: false))
        end

        it { expect_disallowed(*allowed_abilities) }
      end

      context 'with custom_roles license enabled' do
        before do
          stub_licensed_features(licensed_features.merge(custom_roles: true))
        end

        context 'custom role for parent group membership' do
          context 'when a role enables the abilities' do
            before do
              create_member_role(parent_group_member_guest)
            end

            it { expect_allowed(*allowed_abilities) }
            it { expect_disallowed(*disallowed_abilities) }
          end

          context 'when a role does not enable the abilities' do
            it { expect_disallowed(*allowed_abilities) }
          end
        end

        context 'custom role on group membership' do
          context 'when a role enables the abilities' do
            before do
              create_member_role(group_member_guest)
            end

            it { expect_allowed(*allowed_abilities) }
            it { expect_disallowed(*disallowed_abilities) }
          end

          context 'when a role does not enable the abilities' do
            it { expect_disallowed(*allowed_abilities) }
          end
        end
      end
    end

    context 'for a member role with read_vulnerability true' do
      let(:member_role_abilities) { { read_vulnerability: true } }
      let(:allowed_abilities) { [:read_group_security_dashboard] }

      it_behaves_like 'custom roles abilities'

      it 'does not enable to admin_vulnerability' do
        expect(subject).to be_disallowed(:admin_vulnerability)
      end

      it { is_expected.to be_disallowed(:read_dependency) }
    end

    context 'for a member role with admin_vulnerability true' do
      let(:member_role_abilities) { { read_vulnerability: true, admin_vulnerability: true } }
      let(:licensed_features) { { security_inventory: true } }
      let(:allowed_abilities) do
        [:read_group_security_dashboard, :read_security_inventory, :read_vulnerability, :admin_vulnerability]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with read_dependency true' do
      let(:member_role_abilities) { { read_dependency: true } }
      let(:allowed_abilities) { [:read_dependency, :read_licenses] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_group_member true' do
      let(:member_role_abilities) { { admin_group_member: true } }
      let(:allowed_abilities) { [:admin_group_member] }
      let(:disallowed_abilities) { [:activate_group_member] }

      it_behaves_like 'custom roles abilities'

      context 'admin_service_account_member' do
        let_it_be(:guest) { create(:user) }
        let_it_be(:group) { create(:group) }

        let_it_be(:group_member_guest) do
          create(
            :group_member,
            user: guest,
            source: group,
            access_level: Gitlab::Access::GUEST
          )
        end

        let(:role) do
          create(
            :member_role,
            :guest,
            namespace: group,
            admin_group_member: true
          )
        end

        before do
          role.members << group_member_guest
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to be_disallowed(:admin_service_account_member) }

        context 'when service accounts feature enabled' do
          before do
            stub_licensed_features(custom_roles: true, service_accounts: true)
          end

          it { is_expected.to be_allowed(:admin_service_account_member) }
        end
      end
    end

    context 'for a member role with manage_group_access_tokens true' do
      let(:member_role_abilities) { { manage_group_access_tokens: true } }
      let(:allowed_abilities) do
        [:read_resource_access_tokens, :destroy_resource_access_tokens,
         :create_resource_access_tokens, :manage_resource_access_tokens]
      end

      it_behaves_like 'custom roles abilities'

      context 'when resource access token creation is not allowed' do
        before do
          create_member_role(group_member_guest)
          stub_licensed_features(custom_roles: true)
          group.root_ancestor.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
        end

        it { is_expected.to be_allowed(:read_resource_access_tokens, :destroy_resource_access_tokens) }
        it { is_expected.to be_disallowed(:create_resource_access_tokens, :manage_resource_access_tokens) }
      end

      context 'when resource access tokens feature is unavailable' do
        before do
          create_member_role(group_member_guest)
          stub_licensed_features(custom_roles: true)
          stub_ee_application_setting(personal_access_tokens_disabled?: true)
        end

        it { is_expected.to be_disallowed(*allowed_abilities) }
      end
    end

    context 'for a custom role with the `admin_cicd_variables` ability' do
      let(:member_role_abilities) { { admin_cicd_variables: true } }
      let(:allowed_abilities) { [:admin_cicd_variables] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `admin_protected_environments` ability' do
      let(:member_role_abilities) { { admin_protected_environments: true } }
      let(:allowed_abilities) { [:admin_protected_environments] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_compliance_framework true' do
      let(:member_role_abilities) { { read_compliance_dashboard: true, admin_compliance_framework: true } }

      let(:allowed_abilities) do
        [
          :admin_compliance_framework,
          :admin_compliance_pipeline_configuration,
          :read_compliance_dashboard,
          :read_compliance_adherence_report,
          :read_compliance_violations_report
        ]
      end

      context 'when compliance framework feature is available' do
        let(:licensed_features) do
          {
            compliance_framework: true,
            custom_compliance_frameworks: true,
            evaluate_group_level_compliance_pipeline: true,
            group_level_compliance_dashboard: true,
            group_level_compliance_adherence_report: true,
            group_level_compliance_violations_report: true
          }
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'when compliance framework features are unavailable' do
        before do
          create_member_role(group_member_guest)

          stub_licensed_features(
            custom_roles: true,
            custom_compliance_frameworks: false,
            evaluate_group_level_compliance_pipeline: false,
            group_level_compliance_dashboard: false,
            group_level_compliance_adherence_report: false,
            group_level_compliance_violations_report: false
          )
        end

        it { is_expected.to be_disallowed(*allowed_abilities) }
      end
    end

    context 'for a member role with read_compliance_dashboard true' do
      let(:member_role_abilities) { { read_compliance_dashboard: true } }

      let(:allowed_abilities) do
        [
          :read_compliance_dashboard,
          :read_compliance_adherence_report,
          :read_compliance_violations_report
        ]
      end

      context 'when compliance framework feature is available' do
        let(:licensed_features) do
          {
            group_level_compliance_dashboard: true,
            group_level_compliance_adherence_report: true,
            group_level_compliance_violations_report: true
          }
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'for a custom role with the `admin_security_testing` ability' do
        let(:member_role_abilities) { { admin_security_testing: true } }
        let(:licensed_features) do
          { security_dashboard: true,
            secret_push_protection: true,
            group_level_compliance_dashboard: true }
        end

        let(:allowed_abilities) do
          [
            :access_security_and_compliance,
            :read_security_configuration,
            :read_group_security_dashboard,
            :read_security_resource,
            :enable_secret_push_protection
          ]
        end

        it_behaves_like 'custom roles abilities'
      end

      context 'when compliance framework feature is unavailable' do
        before do
          create_member_role(group_member_guest)

          stub_licensed_features(
            custom_roles: true,
            group_level_compliance_dashboard: false,
            group_level_compliance_adherence_report: false,
            group_level_compliance_violations_report: false
          )
        end

        it { is_expected.to be_disallowed(*allowed_abilities) }
      end
    end

    context 'for a custom role with the `remove_group` ability' do
      let(:member_role_abilities) { { remove_group: true } }
      let(:allowed_abilities) { [:remove_group, :view_edit_page] }

      it_behaves_like 'custom roles abilities'

      context 'when the group is a top level group' do
        before do
          create_member_role(parent_group_member_guest)
          stub_licensed_features(custom_roles: true)
        end

        subject { described_class.new(current_user, parent_group) }

        it { is_expected.to be_disallowed(*allowed_abilities) }
      end
    end

    context 'for a custom role with the `admin_push_rules` ability' do
      let(:member_role_abilities) { { admin_push_rules: true } }
      let(:allowed_abilities) { [:admin_push_rules] }

      it_behaves_like 'custom roles abilities'

      context 'when push rules feature is enabled' do
        before do
          stub_licensed_features(
            custom_roles: true,
            push_rules: true,
            commit_committer_check: true,
            commit_committer_name_check: true,
            reject_unsigned_commits: true,
            reject_non_dco_commits: true
          )

          create_member_role(group_member_guest)
        end

        it do
          is_expected.to be_allowed(
            :change_push_rules,
            :change_commit_committer_check,
            :change_commit_committer_name_check,
            :change_reject_unsigned_commits,
            :change_reject_non_dco_commits
          )
        end
      end
    end

    context 'for a custom role with the `manage_security_policy_link` ability' do
      let(:member_role_abilities) { { manage_security_policy_link: true } }
      let(:licensed_features) { { security_orchestration_policies: true } }

      let(:allowed_abilities) do
        [:read_security_orchestration_policies, :read_security_orchestration_policy_project,
         :update_security_orchestration_policy_project]
      end

      let(:disallowed_abilities) do
        [:modify_security_policy]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_web_hook true' do
      let(:member_role_abilities) { { admin_web_hook: true } }
      let(:allowed_abilities) { [:admin_web_hook, :read_web_hook] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `manage_deploy_tokens` permission' do
      let(:member_role_abilities) { { manage_deploy_tokens: true } }

      let(:allowed_abilities) do
        [:manage_deploy_tokens, :read_deploy_token, :create_deploy_token, :destroy_deploy_token, :view_edit_page]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `manage_merge_request_settings` ability' do
      let(:member_role_abilities) { { read_code: true, manage_merge_request_settings: true } }
      let(:allowed_abilities) { [:manage_merge_request_settings, :view_edit_page] }

      it_behaves_like 'custom roles abilities'

      context 'when the group is a top level group and the `merge_request_approvers` feature is available' do
        before do
          create_member_role(parent_group_member_guest)
          stub_licensed_features(custom_roles: true, merge_request_approvers: true)
        end

        subject { described_class.new(current_user, parent_group) }

        it { is_expected.to be_allowed(:admin_merge_request_approval_settings) }
      end
    end

    context 'for a member role with `admin_runners` true' do
      let(:member_role_abilities) { { admin_runners: true } }
      let(:allowed_abilities) do
        [
          :admin_runner,
          :create_runner,
          :read_group_all_available_runners,
          :read_group_runners
        ]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a custom role with the `admin_integrations` permission' do
      let(:member_role_abilities) { { admin_integrations: true } }

      let(:allowed_abilities) do
        [:admin_integrations]
      end

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with read_crm_contact true' do
      let(:member_role_abilities) { { read_crm_contact: true } }
      let(:allowed_abilities) { [:read_crm_contact] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with read_runners true' do
      let(:member_role_abilities) { { read_runners: true } }
      let(:allowed_abilities) { [:read_group_runners] }

      it_behaves_like 'custom roles abilities'
    end

    context 'for a member role with admin_security_labels true' do
      let(:member_role_abilities) { { admin_security_labels: true } }
      let(:allowed_abilities) { [:admin_security_labels] }

      it_behaves_like 'custom roles abilities'
    end
  end

  describe ':destroy_group policy' do
    context 'when default_project_deletion_protection is set to true' do
      before do
        stub_application_setting(default_project_deletion_protection: true)
        stub_licensed_features(custom_roles: true)
      end

      context 'with admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:remove_group) }
      end

      context 'with owner' do
        let(:current_user) { owner }

        context 'when group is empty' do
          it { is_expected.to be_allowed(:remove_group) }
        end

        context 'when group has only inactive project' do
          let_it_be(:project_marked_for_deletion) do
            create(:project, group: group, marked_for_deletion_at: Time.current)
          end

          let_it_be(:project_archived) do
            create(:project, group: group, archived: true)
          end

          it { is_expected.to be_allowed(:remove_group) }
        end

        context 'when group has at least one active project' do
          let_it_be(:project) do
            create(:project, group: group)
          end

          it { is_expected.to be_disallowed(:remove_group) }
        end
      end
    end
  end

  context 'for :read_limit_alert' do
    context 'when the user is a guest member of the group' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_limit_alert) }
    end

    context 'when the user is not a member of the group' do
      let(:current_user) { non_group_member }

      it { is_expected.to be_disallowed(:read_limit_alert) }
    end
  end

  context 'saved replies permissions' do
    let(:current_user) { owner }

    context 'when no license is present' do
      before do
        stub_licensed_features(group_saved_replies: false)
      end

      it { is_expected.to be_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
    end

    context 'with correct license' do
      before do
        stub_licensed_features(group_saved_replies: true)
      end

      it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_allowed(:read_saved_replies) }

        it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_allowed(:read_saved_replies) }

        it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a planner' do
        let(:current_user) { planner }

        it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a guest member of the group' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end
    end
  end

  describe 'read_runner_cloud_provisioning_info policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_runner_cloud_provisioning_info) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_runner_cloud_provisioning_info) }
      end
    end
  end

  describe 'read_runner_gke_provisioning_info policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_runner_gke_provisioning_info) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_runner_gke_provisioning_info) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_runner_gke_provisioning_info) }
      end
    end
  end

  describe 'provision_cloud_runner policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:provision_cloud_runner) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:provision_cloud_runner) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:provision_cloud_runner) }
      end
    end
  end

  describe 'provision_gke_runner policy' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:provision_gke_runner) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'the user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:provision_gke_runner) }
      end

      context 'the user is a guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:provision_gke_runner) }
      end
    end
  end

  describe 'read_jobs_statistics' do
    let(:current_user) { developer }

    it { is_expected.to be_disallowed(:read_jobs_statistics) }

    context 'when runner performance insights feature is available' do
      before do
        stub_licensed_features(runner_performance_insights_for_namespace: true)
      end

      it { is_expected.to be_disallowed(:read_jobs_statistics) }

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:read_jobs_statistics) }
      end
    end
  end

  describe 'read_runner_usage' do
    where(:licensed, :current_user, :enable_admin_mode, :clickhouse_configured, :expected) do
      true  | ref(:admin)      | true  | true  | true
      false | ref(:maintainer) | false | true  | false
      true  | ref(:maintainer) | false | false | false
      true  | ref(:maintainer) | false | true  | true
      true  | ref(:auditor)    | false | true  | false
      true  | ref(:developer)  | false | true  | false
    end

    with_them do
      before do
        stub_licensed_features(runner_performance_insights_for_namespace: licensed)

        enable_admin_mode!(admin) if enable_admin_mode

        allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
      end

      it 'matches expectation' do
        if expected
          is_expected.to be_allowed(:read_runner_usage)
        else
          is_expected.to be_disallowed(:read_runner_usage)
        end
      end
    end
  end

  describe 'web_hooks' do
    let(:current_user) { maintainer }

    it { is_expected.to be_disallowed(:read_web_hook, :admin_web_hook) }

    context 'when user is an owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_web_hook, :admin_web_hook) }
    end
  end

  describe 'enable_secret_push_protection' do
    using RSpec::Parameterized::TableSyntax

    where(:current_user, :licensed, :match_expected_result) do
      ref(:owner)      | true  | be_allowed(:enable_secret_push_protection)
      ref(:maintainer) | true  | be_allowed(:enable_secret_push_protection)
      ref(:developer)  | true  | be_disallowed(:enable_secret_push_protection)
      ref(:owner)      | false | be_disallowed(:enable_secret_push_protection)
      ref(:maintainer) | false | be_disallowed(:enable_secret_push_protection)
      ref(:developer)  | false | be_disallowed(:enable_secret_push_protection)
    end

    with_them do
      before do
        stub_licensed_features(secret_push_protection: licensed)
      end

      it { is_expected.to match_expected_result }
    end

    describe 'when the group does not have the correct license' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:enable_secret_push_protection) }
    end
  end

  describe 'admin_licensed_seat' do
    context 'when user is an owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:admin_licensed_seat) }
    end

    context 'when user is not an owner' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:admin_licensed_seat) }
    end
  end

  describe 'bulk_admin_epic' do
    context 'when bulk_edit_feature_available is true' do
      before do
        stub_licensed_features(epics: true, group_bulk_edit: true)
      end

      context 'when user is planner or reporter' do
        where(role: %w[planner reporter])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_allowed(:bulk_admin_epic) }
        end
      end

      context 'when user is not reporter or better' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:bulk_admin_epic) }
      end
    end

    context 'when bulk_edit_feature_available is false' do
      before do
        stub_licensed_features(epics: true, group_bulk_edit: false)
      end

      context 'when user is guest, planner or reporter' do
        where(role: %w[guest planner reporter])

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(:bulk_admin_epic) }
        end
      end
    end
  end

  describe 'generate_description' do
    context "when feature is authorized" do
      before do
        stub_licensed_features(epics: true)

        allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
          allow(instance).to receive(:allowed?).and_return(true)
        end
      end

      context 'with planner+' do
        let(:current_user) { planner }

        context 'when user can create issue' do
          it { is_expected.to be_allowed(:generate_description) }
        end
      end

      context 'with guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:generate_description) }
      end
    end

    context "when feature is not authorized" do
      let(:current_user) { owner }

      before do
        allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
          allow(instance).to receive(:allowed?).and_return(false)
        end
      end

      it { is_expected.to be_disallowed(:generate_description) }
    end
  end

  describe 'access_ai_review_mr' do
    let(:current_user) { owner }

    where(:duo_features_enabled, :allowed_to_use, :enabled_for_user) do
      false  | false | be_disallowed(:access_ai_review_mr)
      true   | false | be_disallowed(:access_ai_review_mr)
      false  | true  | be_disallowed(:access_ai_review_mr)
      true   | true  | be_allowed(:access_ai_review_mr)
    end

    with_them do
      before do
        allow(group).to receive(:duo_features_enabled).and_return(duo_features_enabled)

        allow(current_user).to receive(:allowed_to_use?)
          .with(:review_merge_request, licensed_feature: :review_merge_request).and_return(allowed_to_use)
      end

      it { is_expected.to enabled_for_user }
    end
  end

  describe 'admin custom roles', :enable_admin_mode do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:user) { create(:user) }

    subject { described_class.new(user, group) }

    before do
      create(:admin_member_role, :read_admin_cicd, user: user)
    end

    context 'when user can read_admin_cicd' do
      context 'when custom roles feature is unavailable' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be_disallowed(:read_group_metadata) }
      end

      context 'when custom roles feature is available' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { is_expected.to be_allowed(:read_group_metadata) }
      end
    end
  end

  describe 'admin_group_model_selection' do
    let(:feature_flags_enabled) { true }
    let(:namespace_duo_enabled) { true }
    let(:with_self_hosted) { false }

    before do
      stub_feature_flags(ai_model_switching: feature_flags_enabled)
      allow(::Ai::Setting).to receive(:self_hosted?).and_return(with_self_hosted)

      group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)
    end

    context 'when user can not admin the group' do
      let(:current_user) { maintainer }

      it { is_expected.to be_disallowed(:admin_group_model_selection) }
    end

    context 'with sub-groups' do
      let(:current_user) { owner }
      let(:parent_group) { create(:group) }
      let(:group) { create(:group, parent: parent_group) }

      it { is_expected.to be_disallowed(:admin_group_model_selection) }
    end

    context 'when user can admin the group' do
      let(:current_user) { owner }

      where(:feature_flags_enabled, :namespace_duo_enabled, :with_self_hosted, :enabled_for_user) do
        false | false | false | be_disallowed(:admin_group_model_selection)
        false | false | true | be_disallowed(:admin_group_model_selection)
        true | false | false | be_disallowed(:admin_group_model_selection)
        true | false | true | be_disallowed(:admin_group_model_selection)
        false  | true  | false | be_disallowed(:admin_group_model_selection)
        true   | true  | false | be_allowed(:admin_group_model_selection)
        true | true | true | be_disallowed(:admin_group_model_selection)
      end

      with_them do
        it { is_expected.to enabled_for_user }
      end
    end
  end

  describe 'admin_duo_workflow' do
    let(:policy) { :admin_duo_workflow }

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      where(:role) do
        %i[guest planner reporter developer maintainer owner]
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to be_disallowed(policy) }
      end
    end

    context 'when the feature flag is enabled' do
      context 'when duo_features is not enabled for the group' do
        before do
          group.namespace_settings.update!(duo_features_enabled: false)
        end

        where(:role) do
          %i[guest planner reporter developer maintainer owner]
        end

        with_them do
          let(:current_user) { public_send(role) }

          it { is_expected.to be_disallowed(policy) }
        end
      end

      context 'when duo_features is enabled for the group' do
        before do
          group.namespace_settings.update!(duo_features_enabled: true)

          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
        end

        context 'when stage check says workflow is not available' do
          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(false)
          end

          where(:role) do
            %i[guest planner reporter developer maintainer owner]
          end

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to be_disallowed(policy) }
          end
        end

        context 'when stage check says workflow is available' do
          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
          end

          context 'when user cannot use duo_agent_platform' do
            where(:role, :allowed) do
              :guest      | false
              :planner    | false
              :reporter   | false
              :developer  | false
              :maintainer | false
              :owner      | true
            end

            with_them do
              let(:current_user) { public_send(role) }

              it { is_expected.to(be_disallowed(policy)) }
            end
          end

          context 'when user can use duo_agent_platform' do
            before do
              allow(current_user).to receive(:allowed_to_use?).and_return(true)
            end

            where(:role, :allowed) do
              :guest      | false
              :planner    | false
              :reporter   | false
              :developer  | false
              :maintainer | false
              :owner      | true
            end

            with_them do
              let(:current_user) { public_send(role) }

              it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
            end
          end
        end
      end
    end
  end

  describe 'security inventory' do
    context 'when security inventory is available' do
      before do
        stub_licensed_features(security_inventory: true)
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_security_inventory) }

        context 'when the security_inventory_dashboard feature flag is disabled' do
          before do
            stub_feature_flags(security_inventory_dashboard: false)
          end

          it { is_expected.to be_disallowed(:read_security_inventory) }
        end
      end

      context 'when user is reporter' do
        let(:current_user) { reporter }

        it { is_expected.to be_disallowed(:read_security_inventory) }
      end
    end

    context 'when security inventory is not available' do
      before do
        stub_licensed_features(security_inventory: false)
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:read_security_inventory) }
      end
    end
  end

  describe 'security labels' do
    context 'when security labels are available' do
      before do
        stub_licensed_features(security_labels: true)
      end

      context 'when user is maintainer' do
        let(:current_user) { maintainer }

        it { is_expected.to be_allowed(:admin_security_labels) }
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { is_expected.to be_disallowed(:admin_security_labels) }
      end
    end
  end
end
