# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Group, feature_category: :groups_and_projects do
  include LoginHelpers
  using RSpec::Parameterized::TableSyntax
  include ReactiveCachingHelpers

  let(:group) { create(:group) }

  it { is_expected.to include_module(EE::Group) }
  it { is_expected.to be_kind_of(ReactiveCaching) }

  describe 'associations' do
    it { is_expected.to have_many(:audit_events).dependent(false) }
    # shoulda-matchers attempts to set the association to nil to ensure
    # the presence check works, but since this is a private method that
    # method can't be called with a public_send.
    it { is_expected.to belong_to(:file_template_project).class_name('Project').without_validating_presence }
    it { is_expected.to have_many(:ip_restrictions) }
    it { is_expected.to have_many(:allowed_email_domains) }
    it { is_expected.to have_many(:compliance_management_frameworks) }
    it { is_expected.to have_one(:google_cloud_platform_workload_identity_federation_integration) }
    it { is_expected.to have_one(:amazon_q_integration) }
    it { is_expected.to have_one(:group_wiki_repository) }
    it { is_expected.to belong_to(:push_rule).inverse_of(:group) }
    it { is_expected.to have_many(:saml_group_links) }
    it { is_expected.to have_many(:epics) }
    it { is_expected.to have_many(:epic_boards).inverse_of(:group) }
    it { is_expected.to have_many(:provisioned_user_details).inverse_of(:provisioned_by_group) }
    it { is_expected.to have_many(:provisioned_users) }
    it { is_expected.to have_one(:group_merge_request_approval_setting) }
    it { is_expected.to have_many(:repository_storage_moves) }
    it { is_expected.to have_many(:iterations) }
    it { is_expected.to have_many(:iterations_cadences) }
    it { is_expected.to have_many(:approval_rules).class_name('ApprovalRules::ApprovalGroupRule').inverse_of(:group) }
    it { is_expected.to have_many(:epic_board_recent_visits).inverse_of(:group) }
    it { is_expected.to have_many(:external_audit_event_destinations) }
    it { is_expected.to have_many(:external_audit_event_streaming_destinations) }
    it { is_expected.to have_many(:google_cloud_logging_configurations) }
    it { is_expected.to have_many(:amazon_s3_configurations) }
    it { is_expected.to have_one(:analytics_dashboards_pointer) }
    it { is_expected.to have_one(:analytics_dashboards_configuration_project) }
    it { is_expected.to have_one(:value_stream_dashboard_aggregation).with_foreign_key(:namespace_id) }
    it { is_expected.to have_one(:index_status).class_name(Elastic::GroupIndexStatus).with_foreign_key(:namespace_id).dependent(:destroy) }
    it { is_expected.to have_many(:security_exclusions).class_name('Security::GroupSecurityExclusion') }
    it { is_expected.to have_many(:enterprise_users).through(:enterprise_user_details).source(:user) }
    it { is_expected.to have_many(:subscription_seat_assignments).class_name('GitlabSubscriptions::SeatAssignment') }
    it { is_expected.to have_many(:custom_lifecycles).class_name('WorkItems::Statuses::Custom::Lifecycle') }

    it do
      is_expected.to have_many(:ai_feature_settings)
         .class_name('Ai::ModelSelection::NamespaceFeatureSetting')
         .with_foreign_key(:namespace_id)
         .inverse_of(:namespace)
    end

    it do
      is_expected.to have_many(:enterprise_user_details)
          .class_name('UserDetail')
          .with_foreign_key(:enterprise_group_id)
          .inverse_of(:enterprise_group)
    end

    it do
      is_expected.to have_many(:ssh_certificates).class_name('Groups::SshCertificate')
        .with_foreign_key(:namespace_id).inverse_of(:group)
    end

    it_behaves_like 'model with wiki' do
      let(:container) { create(:group, :nested, :wiki_repo) }
      let(:container_without_wiki) { create(:group, :nested) }
    end
  end

  describe 'scopes' do
    describe '.with_custom_file_templates' do
      let!(:excluded_group) { create(:group) }
      let(:included_group) { create(:group) }
      let(:project) { create(:project, namespace: included_group) }

      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)

        included_group.update!(file_template_project: project)
      end

      subject(:relation) { described_class.with_custom_file_templates }

      it { is_expected.to contain_exactly(included_group) }

      it 'preloads everything needed to show a valid checked_file_template_project' do
        group = relation.first

        expect { group.checked_file_template_project }.not_to exceed_query_limit(0)

        expect(group.checked_file_template_project).to be_present
      end
    end

    describe '.with_saml_provider' do
      subject(:relation) { described_class.with_saml_provider }

      it 'preloads saml_providers' do
        create(:saml_provider, group: group)

        expect(relation.first.association(:saml_provider)).to be_loaded
      end
    end

    describe '.for_epics' do
      let_it_be(:epic1) { create(:epic) }
      let_it_be(:epic2) { create(:epic) }

      it 'returns groups only for selected epics' do
        epics = ::Epic.where(id: epic1)
        expect(described_class.for_epics(epics)).to contain_exactly(epic1.group)
      end
    end

    describe '.with_managed_accounts_enabled' do
      subject { described_class.with_managed_accounts_enabled }

      let!(:group_with_with_managed_accounts_enabled) { create(:group_with_managed_accounts) }
      let!(:group_without_managed_accounts_enabled) { create(:group) }

      it 'includes the groups that has managed accounts enabled' do
        expect(subject).to contain_exactly(group_with_with_managed_accounts_enabled)
      end
    end

    describe '.with_no_pat_expiry_policy' do
      subject { described_class.with_no_pat_expiry_policy }

      let!(:group_with_pat_expiry_policy) { create(:group, max_personal_access_token_lifetime: 1) }
      let!(:group_with_no_pat_expiry_policy) { create(:group, max_personal_access_token_lifetime: nil) }

      it 'includes the groups that has no PAT expiry policy set' do
        expect(subject).to contain_exactly(group_with_no_pat_expiry_policy)
      end
    end

    describe '.user_is_member' do
      let_it_be(:user) { create(:user) }
      let_it_be(:not_member_group) { create(:group) }
      let_it_be(:shared_group) { create(:group) }
      let_it_be(:direct_group) { create(:group) }
      let_it_be(:inherited_group) { create(:group, parent: direct_group) }
      let_it_be(:group_link) { create(:group_group_link, shared_group: shared_group, shared_with_group: direct_group) }
      let_it_be(:minimal_access_group) { create(:group) }

      before do
        direct_group.add_guest(user)
        create(:group_member, :minimal_access, user: user, source: minimal_access_group)
      end

      it 'returns only groups where user is direct or indirect member ignoring minimal access level' do
        expect(described_class.user_is_member(user)).to match_array([shared_group, direct_group, inherited_group])
      end
    end

    describe '.invited_groups_in_groups_for_hierarchy' do
      let_it_be(:group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: group) }
      let_it_be(:ancestor_invited_group) { create(:group) }
      let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
      let_it_be(:invited_guest_group) { create(:group) }
      let_it_be(:sub_invited_group) { create(:group) }
      let_it_be(:internal_invited_group) { create(:group, parent: group) }

      before_all do
        create(:group_group_link)
        create(:group_group_link, { shared_with_group: sub_invited_group, shared_group: sub_group })
        create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
        create(:group_group_link, :guest, { shared_with_group: invited_guest_group, shared_group: group })
        create(:group_group_link, { shared_with_group: internal_invited_group, shared_group: group })
      end

      context 'with guests' do
        it 'includes all groups from group invites' do
          expect(described_class.invited_groups_in_groups_for_hierarchy(group))
            .to match_array([invited_guest_group, invited_group, sub_invited_group, internal_invited_group])
        end
      end

      context 'without guests' do
        it 'includes all groups from group invites' do
          expect(described_class.invited_groups_in_groups_for_hierarchy(group, true))
            .to match_array([invited_group, sub_invited_group, internal_invited_group])
        end
      end
    end

    describe '.invited_groups_in_projects_for_hierarchy' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }
      let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
      let_it_be(:ancestor_invited_group) { create(:group) }
      let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
      let_it_be(:invited_guest_group) { create(:group) }
      let_it_be(:sub_invited_group) { create(:group) }
      let_it_be(:internal_invited_group) { create(:group, parent: group) }

      before_all do
        create(:project_group_link)
        create(:project_group_link, project: project, group: invited_group)
        create(:project_group_link, project: sub_group_project, group: sub_invited_group)
        create(:project_group_link, :guest, project: project, group: invited_guest_group)
        create(:project_group_link, project: project, group: internal_invited_group)
      end

      context 'with guests' do
        it 'includes all groups from group invites' do
          expect(described_class.invited_groups_in_projects_for_hierarchy(group))
            .to match_array([invited_group, sub_invited_group, invited_guest_group, internal_invited_group])
        end
      end

      context 'without guests' do
        it 'includes all groups from group invites' do
          expect(described_class.invited_groups_in_projects_for_hierarchy(group, true))
            .to match_array([invited_group, sub_invited_group, internal_invited_group])
        end
      end
    end

    describe '.with_trial_started_on', :saas do
      let(:ten_days_ago) { 10.days.ago }

      it 'returns correct group' do
        create(:group)

        create(
          :gitlab_subscription, :active_trial,
          namespace: create(:group),
          trial_starts_on: 1.day.ago
        )

        create(
          :gitlab_subscription, :active_trial,
          namespace: group,
          trial_starts_on: ten_days_ago
        )

        expect(described_class.with_trial_started_on(ten_days_ago)).to match_array([group])
      end
    end

    describe '.by_repository_storage' do
      let_it_be(:group_with_wiki) { create(:group, :wiki_repo) }
      let_it_be(:group_without_wiki) { create(:group) }

      it 'filters group by repository storage name' do
        groups = described_class.by_repository_storage(group_with_wiki.repository_storage)
        expect(groups).to eq([group_with_wiki])
      end
    end
  end

  describe 'validations' do
    context 'max_personal_access_token_lifetime' do
      before do
        stub_feature_flags(buffered_token_expiration_limit: false)
      end

      it { is_expected.to allow_value(1).for(:max_personal_access_token_lifetime) }
      it { is_expected.to allow_value(nil).for(:max_personal_access_token_lifetime) }
      it { is_expected.to allow_value(10).for(:max_personal_access_token_lifetime) }
      it { is_expected.not_to allow_value("value").for(:max_personal_access_token_lifetime) }
      it { is_expected.not_to allow_value(2.5).for(:max_personal_access_token_lifetime) }
      it { is_expected.not_to allow_value(-5).for(:max_personal_access_token_lifetime) }
      it { is_expected.not_to allow_value(401).for(:max_personal_access_token_lifetime) }
    end

    context 'extended lifetime is selected' do
      it { is_expected.to allow_value(400).for(:max_personal_access_token_lifetime) }
    end

    context 'validates if custom_project_templates_group_id is allowed' do
      let(:subgroup_1) { create(:group, parent: group) }

      it 'rejects change if the assigned group is not a subgroup' do
        group.custom_project_templates_group_id = create(:group).id

        expect(group).not_to be_valid
        expect(group.errors.messages[:custom_project_templates_group_id]).to match_array(['has to be a subgroup of the group'])
      end

      it 'allows value if the assigned value is from a subgroup' do
        group.custom_project_templates_group_id = subgroup_1.id

        expect(group).to be_valid
      end

      it 'rejects change if the assigned value is from a subgroup\'s descendant group' do
        subgroup_1_1 = create(:group, parent: subgroup_1)
        group.custom_project_templates_group_id = subgroup_1_1.id

        expect(group).not_to be_valid
      end

      it 'allows value when it is blank' do
        subgroup = create(:group, parent: group)
        group.update!(custom_project_templates_group_id: subgroup.id)

        group.custom_project_templates_group_id = ""

        expect(group).to be_valid
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:wiki_access_level).to(:group_feature) }
    it { is_expected.to delegate_method(:wiki_access_level=).to(:group_feature).with_arguments(:args) }
    it { is_expected.to delegate_method(:duo_availability).to(:namespace_settings) }
    it { is_expected.to delegate_method(:duo_availability=).to(:namespace_settings).with_arguments(:args) }
    it { is_expected.to delegate_method(:experiment_settings_allowed?).to(:namespace_settings) }
    it { is_expected.to delegate_method(:user_cap_enabled?).to(:namespace_settings) }
    it { is_expected.to delegate_method(:require_dpop_for_manage_api_endpoints?).to(:namespace_settings) }
    it { is_expected.to delegate_method(:require_dpop_for_manage_api_endpoints).to(:namespace_settings) }
    it { is_expected.to delegate_method(:require_dpop_for_manage_api_endpoints=).to(:namespace_settings).with_arguments(:args) }
    it { is_expected.to delegate_method(:disable_invite_members=).to(:namespace_settings).with_arguments(:args) }
    it { is_expected.to delegate_method(:disable_invite_members?).to(:namespace_settings) }
    it { is_expected.to delegate_method(:enterprise_users_extensions_marketplace_enabled=).to(:namespace_settings).with_arguments(:args) }
  end

  describe 'states' do
    it { is_expected.to be_ldap_sync_ready }

    context 'after the start transition' do
      it 'sets the last sync timestamp' do
        expect { group.start_ldap_sync }.to change(group, :ldap_sync_last_sync_at)
      end
    end

    context 'after the finish transition' do
      it 'sets the state to started' do
        group.start_ldap_sync

        expect(group).to be_ldap_sync_started

        group.finish_ldap_sync
      end

      it 'sets last update and last successful update to the same timestamp' do
        group.start_ldap_sync

        group.finish_ldap_sync

        expect(group.ldap_sync_last_update_at)
          .to eq(group.ldap_sync_last_successful_update_at)
      end

      it 'clears previous error message on success' do
        group.start_ldap_sync
        group.mark_ldap_sync_as_failed('Error')
        group.start_ldap_sync

        group.finish_ldap_sync

        expect(group.ldap_sync_error).to be_nil
      end
    end

    context 'after the fail transition' do
      it 'sets the state to failed' do
        group.start_ldap_sync

        group.fail_ldap_sync

        expect(group).to be_ldap_sync_failed
      end

      it 'sets last update timestamp but not last successful update timestamp' do
        group.start_ldap_sync

        group.fail_ldap_sync

        expect(group.ldap_sync_last_update_at)
          .not_to eq(group.ldap_sync_last_successful_update_at)
      end
    end
  end

  describe '.groups_user_can' do
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:internal_subgroup) { create(:group, :internal, parent: public_group) }
    let_it_be(:private_subgroup_1) { create(:group, :private, parent: internal_subgroup) }
    let_it_be(:private_subgroup_2) { create(:group, :private, parent: private_subgroup_1) }
    let_it_be(:shared_with_group) { create(:group, :private) }

    let(:user) { create(:user) }
    let(:groups) { described_class.where(id: [public_group.id, internal_subgroup.id, private_subgroup_1.id, private_subgroup_2.id]) }
    let(:params) { { same_root: true } }
    let(:shared_group_access) { GroupMember::GUEST }

    before do
      create(:group_group_link, { shared_with_group: shared_with_group,
                                  shared_group: private_subgroup_1,
                                  group_access: shared_group_access })
    end

    subject do
      described_class.groups_user_can(groups, user, action, **params)
    end

    shared_examples 'confidential group access permission' do
      context 'when user is guest' do
        before do
          private_subgroup_1.add_guest(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [] }
        end
      end

      context 'when user is planner' do
        before do
          private_subgroup_1.add_planner(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [private_subgroup_1, private_subgroup_2] }
        end
      end

      context 'when user is planner via shared group' do
        let(:shared_group_access) { GroupMember::PLANNER }

        before do
          shared_with_group.add_planner(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [private_subgroup_1, private_subgroup_2] }
        end
      end

      context 'when user is member of a project in the hierarchy' do
        let_it_be(:private_subgroup_with_project) { create(:group, :private, parent: public_group) }
        let_it_be(:project) { create(:project, group: private_subgroup_with_project) }

        let(:user) { create(:user) }
        let(:groups) { described_class.where(id: [private_subgroup_with_project, public_group.id, internal_subgroup.id, private_subgroup_1.id, private_subgroup_2.id]) }

        before do
          project.add_developer(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [] }
        end
      end
    end

    shared_examples 'non-confidential group access permission' do
      context 'when user has minimal access to group' do
        before do
          public_group.add_member(user, Gitlab::Access::MINIMAL_ACCESS)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [public_group, internal_subgroup] }
        end
      end

      context 'when user is a group member' do
        before do
          public_group.add_guest(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [public_group, internal_subgroup, private_subgroup_1, private_subgroup_2] }
        end
      end

      context 'when user is not member of any group' do
        it_behaves_like 'a filter for permissioned groups' do
          let(:user) { create(:user) }
          let(:expected_groups) { [public_group, internal_subgroup] }
        end
      end

      context 'when user has membership from a group share' do
        let_it_be(:user) { create(:user) }

        before do
          shared_with_group.add_guest(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [public_group, internal_subgroup, private_subgroup_1, private_subgroup_2] }
        end
      end

      context 'when user is member of a project in the hierarchy' do
        let_it_be(:private_subgroup_with_project) { create(:group, :private, parent: public_group) }
        let_it_be(:project) { create(:project, group: private_subgroup_with_project) }

        let(:user) { create(:user) }
        let(:groups) { described_class.where(id: [private_subgroup_with_project, public_group.id, internal_subgroup.id, private_subgroup_1.id, private_subgroup_2.id]) }

        before do
          project.add_developer(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [public_group, internal_subgroup, private_subgroup_with_project] }
        end
      end

      context 'when user is member of a child group that has a project' do
        let_it_be(:project) { create(:project, group: private_subgroup_2) }

        before do
          private_subgroup_2.add_guest(user)
        end

        it_behaves_like 'a filter for permissioned groups' do
          let(:expected_groups) { [public_group, internal_subgroup, private_subgroup_1, private_subgroup_2] }
        end
      end
    end

    shared_examples 'a filter for permissioned groups' do
      context 'with epics enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when groups array is empty' do
          let(:groups) { [] }

          it 'does not use filter optimization' do
            expect(described_class).not_to receive(:filter_groups_user_can)

            expect(subject).to be_empty
          end
        end

        it 'uses filter optmization to return groups with access' do
          expect(described_class).not_to receive(:filter_groups_user_can)

          expect(subject).to match_array(expected_groups)
        end

        context 'when same_root is false' do
          let(:params) { { same_root: false } }

          it 'does not use filter optimization' do
            expect(described_class).not_to receive(:filter_groups_user_can)

            expect(subject).to match_array(expected_groups)
          end
        end
      end

      context 'with epics disabled' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'returns an empty list' do
          expect(subject).to be_empty
        end
      end
    end

    context 'for :read_epic permission' do
      let(:action) { :read_epic }

      it_behaves_like 'non-confidential group access permission'
    end

    context 'for :read_work_item permission' do
      let(:action) { :read_work_item }

      it_behaves_like 'non-confidential group access permission'
    end

    context 'for :read_confidential_epic permission' do
      let(:action) { :read_confidential_epic }

      it_behaves_like 'confidential group access permission'
    end

    context 'for :read_confidential_issues permission' do
      let(:action) { :read_confidential_issues }

      it_behaves_like 'confidential group access permission'
    end

    context 'when action is not allowed to use filtering optmization' do
      let(:action) { :read_nested_project_resources }

      before do
        private_subgroup_1.add_reporter(user)
      end

      it 'returns groups without using filter optimization' do
        expect(described_class).not_to receive(:filter_groups_user_can)

        expect(subject).to match_array([public_group, internal_subgroup, private_subgroup_1, private_subgroup_2])
      end
    end

    context 'getting group root ancestor' do
      before do
        public_group.add_reporter(user)
      end

      shared_examples 'group root ancestor' do
        it 'does not exceed SQL queries count' do
          groups = described_class.where(id: private_subgroup_1)
          control = ActiveRecord::QueryRecorder.new do
            described_class.groups_user_can(groups, user, :read_epic, **params)
          end

          groups = described_class.where(id: [private_subgroup_1, private_subgroup_2])
          expect { described_class.groups_user_can(groups, user, :read_epic, **params) }
            .not_to exceed_query_limit(control).with_threshold(extra_query_count)
        end
      end

      context 'when same_root is false' do
        let(:params) { { same_root: false } }

        # extra 6 queries:
        # * getting root_ancestor
        # * getting root ancestor's saml_provider
        # * check if group has projects
        # * max_member_access_for_user_from_shared_groups
        # * max_member_access_for_user
        # * self_and_ancestors_ids
        it_behaves_like 'group root ancestor' do
          let(:extra_query_count) { 6 }
        end
      end

      context 'when same_root is true' do
        let(:params) { { same_root: true } }

        # avoids 2 queries from the list above:
        # * getting root ancestor
        # * getting root ancestor's saml_provider
        it_behaves_like 'group root ancestor' do
          let(:extra_query_count) { 4 }
        end
      end
    end
  end

  describe '.preload_root_saml_providers' do
    let_it_be(:group1) { create(:group, saml_provider: create(:saml_provider)) }
    let_it_be(:group2) { create(:group, saml_provider: create(:saml_provider)) }
    let_it_be(:subgroup1) do
      create(:group, :private, parent: group1).tap do |group|
        group.association(:parent).reset
      end
    end

    let_it_be(:subgroup2) do
      create(:group, :private, parent: group2).tap do |group|
        group.association(:parent).reset
      end
    end

    let(:groups_to_load) { described_class.where(id: [subgroup1.id, subgroup2.id]) }

    it 'sets root_saml_provider for given groups' do
      # Verify that `parent` is not loaded to prevent skipping the query
      # in Namespaces::Traversal::Linear#root_ancestor
      expect(subgroup1.association(:parent)).not_to be_loaded
      expect(subgroup2.association(:parent)).not_to be_loaded

      described_class.preload_root_saml_providers(groups_to_load)

      expect { groups_to_load.map(&:root_saml_provider) }.not_to exceed_query_limit(0)
      expect(subgroup1.root_saml_provider).to eq(group1.saml_provider)
      expect(subgroup2.root_saml_provider).to eq(group2.saml_provider)
    end
  end

  describe '#vulnerabilities' do
    subject { group.vulnerabilities }

    let(:subgroup) { create(:group, parent: group) }
    let(:group_project) { create(:project, namespace: group) }
    let(:subgroup_project) { create(:project, namespace: subgroup) }
    let(:archived_project) { create(:project, :archived, namespace: group) }
    let(:deleted_project) { create(:project, pending_delete: true, namespace: group) }
    let!(:group_vulnerability) { create(:vulnerability_read, project: group_project).vulnerability }
    let!(:subgroup_vulnerability) { create(:vulnerability_read, project: subgroup_project).vulnerability }
    let!(:archived_vulnerability) { create(:vulnerability_read, project: archived_project).vulnerability }
    let!(:deleted_vulnerability) { create(:vulnerability_read, project: deleted_project).vulnerability }

    it 'returns vulnerabilities for all non-archived projects in the group and its subgroups' do
      is_expected.to contain_exactly(group_vulnerability, subgroup_vulnerability, deleted_vulnerability)
    end
  end

  describe '#vulnerability_reads' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:group_project) { create(:project, namespace: root_group) }
    let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }
    let_it_be(:archived_project) { create(:project, :archived, namespace: root_group) }
    let_it_be(:group_vulnerability_read) { create(:vulnerability_read, project: group_project) }
    let_it_be(:subgroup_vulnerability_read) { create(:vulnerability_read, project: subgroup_project) }
    let_it_be(:archived_vulnerability_read) { create(:vulnerability_read, project: archived_project) }

    let(:expected_vulnerability_reads) do
      [group_vulnerability_read, subgroup_vulnerability_read, archived_vulnerability_read]
    end

    subject { root_group.vulnerability_reads }

    it 'returns vulnerabilities for projects in the group and its subgroups' do
      is_expected.to match_array(expected_vulnerability_reads)
    end
  end

  describe '#next_traversal_ids' do
    subject { group.next_traversal_ids }

    let(:group) { build(:group, traversal_ids: [1, 2, 3]) }

    it { is_expected.to eq([1, 2, 4]) }
  end

  describe '#vulnerability_scanners' do
    subject { group.vulnerability_scanners }

    let(:subgroup) { create(:group, parent: group) }
    let(:unrelated_group) { create(:group) }

    let(:group_project) { create(:project, namespace: group) }
    let(:subgroup_project) { create(:project, namespace: subgroup) }
    let(:archived_project) { create(:project, :archived, namespace: group) }
    let(:deleted_project) { create(:project, pending_delete: true, namespace: group) }
    let(:unrelated_project) { create(:project, namespace: unrelated_group) }

    let!(:group_vulnerability_scanner) { create(:vulnerabilities_scanner, project: group_project) }
    let!(:subgroup_vulnerability_scanner) { create(:vulnerabilities_scanner, project: subgroup_project) }
    let!(:archived_vulnerability_scanner) { create(:vulnerabilities_scanner, project: archived_project) }
    let!(:deleted_vulnerability_scanner) { create(:vulnerabilities_scanner, project: deleted_project) }
    let!(:unrelated_vulnerability_scanner) { create(:vulnerabilities_scanner, project: unrelated_project) }

    let!(:group_vulnerability_statistic) { create(:vulnerability_statistic, project: group_project) }
    let!(:subgroup_vulnerability_statistic) { create(:vulnerability_statistic, project: subgroup_project) }
    let!(:archived_vulnerability_statistic) { create(:vulnerability_statistic, project: archived_project) }
    let!(:deleted_vulnerability_statistic) { create(:vulnerability_statistic, project: deleted_project) }
    let!(:unrelated_vulnerability_statistic) { create(:vulnerability_statistic, project: unrelated_project) }

    it 'returns vulnerability scanners for all non-archived projects in the group and its subgroups' do
      is_expected.to include(group_vulnerability_scanner, subgroup_vulnerability_scanner, deleted_vulnerability_scanner)
      is_expected.not_to include(archived_vulnerability_scanner, unrelated_vulnerability_scanner)
    end
  end

  describe '#vulnerability_historical_statistics' do
    let(:date_1) { Date.new(2020, 8, 10) }
    let(:root_group) { create(:group) }
    let(:group) { create(:group, parent: root_group) }
    let(:sub_group) { create(:group, parent: group) }
    let!(:root_vulnerability_namespace_historical_statistic) do
      create(:vulnerability_namespace_historical_statistic, namespace: root_group, date: date_1,
        traversal_ids: root_group.traversal_ids)
    end

    let!(:group_vulnerability_namespace_historical_statistic) do
      create(:vulnerability_namespace_historical_statistic, namespace: group, date: date_1,
        traversal_ids: group.traversal_ids)
    end

    let!(:sub_group_vulnerability_namespace_historical_statistic) do
      create(:vulnerability_namespace_historical_statistic, namespace: sub_group, date: date_1,
        traversal_ids: sub_group.traversal_ids)
    end

    subject do
      root_group.vulnerability_historical_statistics
    end

    it 'returns vulnerability namespace historical statistics for the group and its subgroup' do
      is_expected.to contain_exactly(root_vulnerability_namespace_historical_statistic,
        group_vulnerability_namespace_historical_statistic, sub_group_vulnerability_namespace_historical_statistic)
    end
  end

  describe '#mark_ldap_sync_as_failed' do
    it 'sets the state to failed' do
      group.start_ldap_sync

      group.mark_ldap_sync_as_failed('Error')

      expect(group).to be_ldap_sync_failed
    end

    it 'sets the error message' do
      group.start_ldap_sync

      group.mark_ldap_sync_as_failed('Something went wrong')

      expect(group.ldap_sync_error).to eq('Something went wrong')
    end

    it 'is graceful when current state is not valid for the fail transition' do
      expect(group).to be_ldap_sync_ready
      expect { group.mark_ldap_sync_as_failed('Error') }.not_to raise_error
    end
  end

  describe '#repository_size_limit column' do
    it 'support values up to 8 exabytes' do
      group = create(:group)
      group.update_column(:repository_size_limit, 8.exabytes - 1)

      group.reload

      expect(group.repository_size_limit).to eql(8.exabytes - 1)
    end
  end

  describe '#file_template_project' do
    before do
      stub_licensed_features(custom_file_templates_for_namespace: true)
    end

    it { expect(group.private_methods).to include(:file_template_project) }

    context 'validation' do
      let(:project) { create(:project, namespace: group) }

      it 'is cleared if invalid' do
        invalid_project = create(:project)

        group.file_template_project_id = invalid_project.id

        expect(group).to be_valid
        expect(group.file_template_project_id).to be_nil
      end

      it 'is permitted if valid' do
        valid_project = create(:project, namespace: group)

        group.file_template_project_id = valid_project.id

        expect(group).to be_valid
        expect(group.file_template_project_id).to eq(valid_project.id)
      end
    end
  end

  describe '#ip_restriction_ranges' do
    context 'group with no associated ip_restriction records' do
      it 'returns nil' do
        expect(group.ip_restriction_ranges).to eq(nil)
      end
    end

    context 'group with associated ip_restriction records' do
      let(:ranges) { ['192.168.0.0/24', '10.0.0.0/8'] }

      before do
        ranges.each do |range|
          create(:ip_restriction, group: group, range: range)
        end
      end

      it 'returns a comma separated string of ranges of its ip_restriction records' do
        expect(group.ip_restriction_ranges.split(',')).to contain_exactly(*ranges)
      end
    end
  end

  describe '#root_ancestor_ip_restrictions' do
    let(:root_group) { create(:group) }
    let!(:ip_restriction) { create(:ip_restriction, group: root_group) }

    it 'returns the ip restrictions configured for the root group' do
      nested_group = create(:group, parent: root_group)
      deep_nested_group = create(:group, parent: nested_group)
      very_deep_nested_group = create(:group, parent: deep_nested_group)

      expect(root_group.root_ancestor_ip_restrictions).to contain_exactly(ip_restriction)
      expect(nested_group.root_ancestor_ip_restrictions).to contain_exactly(ip_restriction)
      expect(deep_nested_group.root_ancestor_ip_restrictions).to contain_exactly(ip_restriction)
      expect(very_deep_nested_group.root_ancestor_ip_restrictions).to contain_exactly(ip_restriction)
    end
  end

  describe '#allowed_email_domains_list' do
    subject { group.allowed_email_domains_list }

    context 'group with no associated allowed_email_domains records' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'group with associated allowed_email_domains records' do
      let(:domains) { ['acme.com', 'twitter.com'] }

      before do
        domains.each do |domain|
          create(:allowed_email_domain, group: group, domain: domain)
        end
      end

      it 'returns a comma separated string of domains of its allowed_email_domains records' do
        expect(subject).to eq(domains.join(","))
      end
    end
  end

  describe '#root_ancestor_allowed_email_domains' do
    let(:root_group) { create(:group) }
    let!(:allowed_email_domain) { create(:allowed_email_domain, group: root_group) }

    it 'returns the email domain restrictions configured for the root group' do
      nested_group = create(:group, parent: root_group)
      deep_nested_group = create(:group, parent: nested_group)
      very_deep_nested_group = create(:group, parent: deep_nested_group)

      expect(root_group.root_ancestor_allowed_email_domains).to contain_exactly(allowed_email_domain)
      expect(nested_group.root_ancestor_allowed_email_domains).to contain_exactly(allowed_email_domain)
      expect(deep_nested_group.root_ancestor_allowed_email_domains).to contain_exactly(allowed_email_domain)
      expect(very_deep_nested_group.root_ancestor_allowed_email_domains).to contain_exactly(allowed_email_domain)
    end
  end

  describe '#owner_of_email?', :saas do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: subgroup) }

    let!(:verified_domain) { create(:pages_domain, project: project1) }
    let!(:unverified_domain) { create(:pages_domain, :unverified, project: project2) }

    let(:email_with_verified_domain) { "example@#{verified_domain.domain}" }
    let(:email_with_unverified_domain) { "example@#{unverified_domain.domain}" }
    let(:email_with_unverified_subdomain) { "example@subdomain.#{verified_domain.domain}" }

    context 'when domain_verification feature is licensed' do
      before do
        stub_licensed_features(domain_verification: true)
      end

      it 'returns true for email with verified domain' do
        expect(group.owner_of_email?(email_with_verified_domain)).to eq(true)
      end

      it 'returns false for email with unverified domain' do
        expect(group.owner_of_email?(email_with_unverified_domain)).to eq(false)
      end

      it 'returns false for email with unverified subdomain of verified domain' do
        expect(group.owner_of_email?(email_with_unverified_subdomain)).to eq(false)
      end

      it 'ignores case sensitivity' do
        verified_domain.update!(domain: verified_domain.domain.capitalize)

        expect(group.owner_of_email?(email_with_verified_domain.upcase)).to eq(true)
      end

      it 'returns false when the receiver is subgroup' do
        expect(subgroup.owner_of_email?(email_with_verified_domain)).to eq(false)
      end

      it 'returns false when email format is invalid' do
        expect(group.owner_of_email?('invalid_email_format')).to eq(false)
      end
    end

    context 'when domain_verification feature is not licensed' do
      before do
        stub_licensed_features(domain_verification: false)
      end

      it 'returns false for email with verified domain' do
        expect(group.owner_of_email?(email_with_verified_domain)).to eq(false)
      end
    end
  end

  describe '#predefined_push_rule' do
    context 'group with no associated push_rules record' do
      let!(:sample) { create(:push_rule_sample) }

      it 'returns instance push rule' do
        expect(group.predefined_push_rule).to eq(sample)
      end
    end

    context 'group with associated push_rules record' do
      context 'with its own push rule' do
        let(:push_rule) { create(:push_rule) }

        it 'returns its own push rule' do
          group.update!(push_rule: push_rule)

          expect(group.predefined_push_rule).to eq(push_rule)
        end
      end

      context 'with push rule from ancestor' do
        let(:group) { create(:group, push_rule: push_rule) }
        let(:push_rule) { create(:push_rule) }
        let(:subgroup_1) { create(:group, parent: group) }
        let(:subgroup_1_1) { create(:group, parent: subgroup_1) }

        it 'returns push rule from closest ancestor' do
          expect(subgroup_1_1.predefined_push_rule).to eq(push_rule)
        end
      end
    end

    context 'there are no push rules' do
      it 'returns nil' do
        expect(group.predefined_push_rule).to be_nil
      end
    end
  end

  describe '#checked_file_template_project' do
    let(:valid_project) { create(:project, namespace: group) }

    subject { group.checked_file_template_project }

    context 'licensed' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      it 'returns nil for an invalid project' do
        group.file_template_project = create(:project)

        is_expected.to be_nil
      end

      it 'returns a valid project' do
        group.file_template_project = valid_project

        is_expected.to eq(valid_project)
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: false)
      end

      it 'returns nil for a valid project' do
        group.file_template_project = valid_project

        is_expected.to be_nil
      end
    end
  end

  describe '#checked_file_template_project_id' do
    let(:valid_project) { create(:project, namespace: group) }

    subject { group.checked_file_template_project_id }

    context 'licensed' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      it 'returns nil for an invalid project' do
        group.file_template_project = create(:project)

        is_expected.to be_nil
      end

      it 'returns the ID for a valid project' do
        group.file_template_project = valid_project

        is_expected.to eq(valid_project.id)
      end

      context 'unlicensed' do
        before do
          stub_licensed_features(custom_file_templates_for_namespace: false)
        end

        it 'returns nil for a valid project' do
          group.file_template_project = valid_project

          is_expected.to be_nil
        end
      end
    end
  end

  describe '#group_project_template_available?' do
    subject { group.group_project_template_available? }

    context 'licensed' do
      before do
        stub_licensed_features(group_project_templates: true)
      end

      it 'returns true for licensed instance' do
        is_expected.to be true
      end

      context 'when in need of checking plan', :saas do
        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:should_check_namespace_plan?).and_return(true)
        end

        it 'returns true for groups in proper plan' do
          create(:gitlab_subscription, :ultimate, namespace: group)

          is_expected.to be true
        end

        it 'returns false for groups with group template already set but not in proper plan' do
          group.update!(custom_project_templates_group_id: create(:group, parent: group).id)
          group.reload

          is_expected.to be false
        end
      end

      context 'unlicensed' do
        before do
          stub_licensed_features(group_project_templates: false)
        end

        it 'returns false for unlicensed instance' do
          is_expected.to be false
        end
      end
    end
  end

  describe '#scoped_variables_available?' do
    let(:group) { create(:group) }

    subject { group.scoped_variables_available? }

    before do
      stub_licensed_features(group_scoped_ci_variables: feature_available)
    end

    context 'licensed feature is available' do
      let(:feature_available) { true }

      it { is_expected.to be true }
    end

    context 'licensed feature is not available' do
      let(:feature_available) { false }

      it { is_expected.to be false }
    end
  end

  describe '#minimal_access_role_allowed?' do
    subject { group.minimal_access_role_allowed? }

    context 'licensed' do
      before do
        stub_licensed_features(minimal_access_role: true)
      end

      it 'returns true for licensed instance' do
        is_expected.to be true
      end

      it 'returns false for subgroup in licensed instance' do
        expect(create(:group, parent: group).minimal_access_role_allowed?).to be false
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(minimal_access_role: false)
      end

      it 'returns false unlicensed instance' do
        is_expected.to be false
      end
    end
  end

  describe '#member?' do
    let(:group) { create(:group) }
    let(:user) { create(:user) }

    subject { group.member?(user) }

    before do
      create(:group_member, :minimal_access, user: user, source: group) if user
    end

    context 'with `minimal_access_role` not licensed' do
      it { is_expected.to be_falsey }
    end

    context 'with `minimal_access_role` licensed' do
      before do
        stub_licensed_features(minimal_access_role: true)
      end

      context 'when group is a subgroup' do
        let(:group) { create(:group, parent: create(:group)) }

        it { is_expected.to be_falsey }
      end

      context 'when group is a top-level group' do
        it { is_expected.to be_truthy }

        it 'accepts higher level as argument' do
          expect(group.member?(user, ::Gitlab::Access::DEVELOPER)).to be_falsey
        end
      end

      context 'with anonymous user' do
        let(:user) { nil }

        it { is_expected.to be_falsey }
      end

      shared_context 'shared group context' do
        let_it_be(:shared_group) { create(:group) }
        let_it_be(:member_shared) { create(:user) }

        before do
          create(:group_group_link, shared_group: group, shared_with_group: shared_group)
          shared_group.add_developer(member_shared)
        end
      end

      context 'in shared group' do
        include_context 'shared group context'

        it 'returns true for shared group member' do
          expect(group.member?(member_shared)).to be_truthy
        end

        it 'returns true with developer as min_access_level param' do
          expect(group.member?(member_shared, Gitlab::Access::DEVELOPER)).to be_truthy
        end

        it 'returns false with maintainer as min_access_level param' do
          expect(group.member?(member_shared, Gitlab::Access::MAINTAINER)).to be_falsey
        end
      end
    end
  end

  shared_context 'for billable users setup' do
    let_it_be(:group, refind: true) { create(:group_with_plan, plan: :free_plan) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:group_developer) { group.add_developer(create(:user)).user }
    let_it_be(:project_developer) { project.add_developer(create(:user)).user }
    let_it_be(:group_guest) { group.add_guest(create(:user)).user }
    let_it_be(:project_guest) { project.add_guest(create(:user)).user }
    let_it_be(:invited_group) { create(:group) }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)).user }
    let_it_be(:banned_group_user) { create(:group_member, :banned, :developer, source: group).user }
    let_it_be(:banned_project_user) { create(:project_member, :banned, :developer, source: project).user }

    before_all do
      group.add_maintainer(create(:user, :project_bot))
      project.add_maintainer(create(:user, :project_bot))
      create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
      create(:project_group_link, project: project, group: invited_group)
    end
  end

  describe '#billed_user_ids', :saas do
    include_context 'for billable users setup'

    subject(:billed_user_ids) { group.billed_user_ids }

    context 'with guests' do
      it 'includes distinct active users' do
        expect(billed_user_ids[:user_ids]).to match_array([
          group_guest.id,
          project_guest.id,
          group_developer.id,
          project_developer.id,
          invited_developer.id
        ])
        expect(billed_user_ids[:group_member_user_ids]).to match_array([group_guest.id, group_developer.id])
        expect(billed_user_ids[:project_member_user_ids]).to match_array([project_guest.id, project_developer.id])
        expect(billed_user_ids[:shared_group_user_ids]).to match_array([invited_developer.id])
        expect(billed_user_ids[:shared_project_user_ids]).to match_array([invited_developer.id])
      end

      it 'excludes banned members' do
        expect(billed_user_ids[:user_ids]).to exclude(banned_group_user.id, banned_project_user.id)
        expect(billed_user_ids[:group_member_user_ids]).to exclude(banned_group_user.id)
        expect(billed_user_ids[:project_member_user_ids]).to exclude(banned_project_user.id)
      end
    end

    context 'without guests' do
      before do
        group.gitlab_subscription.update!(hosted_plan: create(:ultimate_plan))
      end

      it 'includes distinct active users' do
        expect(billed_user_ids[:user_ids])
          .to match_array([group_developer.id, project_developer.id, invited_developer.id])
        expect(billed_user_ids[:group_member_user_ids]).to match_array([group_developer.id])
        expect(billed_user_ids[:project_member_user_ids]).to match_array([project_developer.id])
        expect(billed_user_ids[:shared_group_user_ids]).to match_array([invited_developer.id])
        expect(billed_user_ids[:shared_project_user_ids]).to match_array([invited_developer.id])
      end
    end
  end

  describe '#billable_members_count', :saas do
    include_context 'for billable users setup'

    subject(:billable_members_count) { group.billable_members_count }

    context 'with guests' do
      it 'provides count of users' do
        expect(billable_members_count).to eq(5)
      end
    end

    context 'without guests' do
      before do
        group.gitlab_subscription.update!(hosted_plan: create(:ultimate_plan))
      end

      it 'provides count of users' do
        expect(billable_members_count).to eq(3)
      end
    end
  end

  describe '#billed_group_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:sub_developer) { sub_group.add_developer(create(:user)).user }
    let_it_be(:guest) { group.add_guest(create(:user)).user }
    let_it_be(:developer) { group.add_developer(create(:user)).user }

    before_all do
      group.add_developer(create(:user, :blocked))
      group.add_maintainer(create(:user, :project_bot))
      group.add_maintainer(create(:user, :alert_bot))
      group.add_maintainer(create(:user, :support_bot))
      group.add_maintainer(create(:user, :visual_review_bot))
      group.add_maintainer(create(:user, :migration_bot))
      group.add_maintainer(create(:user, :security_bot))
      group.add_maintainer(create(:user, :automation_bot))
      group.add_maintainer(create(:user, :admin_bot))
      create(:group_member, :developer)
      create(:project_member, :developer, source: create(:project, namespace: group))
      create(:group_member, :invited, :developer, source: group)
      create(:group_member, :awaiting, :developer, source: group)
      create(:group_member, :minimal_access, source: group)
      create(:group_member, :access_request, :developer, source: group)
    end

    context 'with guests' do
      it 'includes active users' do
        expect(group.billed_group_users).to match_array([developer, guest, sub_developer])
      end
    end

    context 'without guests' do
      it 'includes active users' do
        expect(group.billed_group_users(exclude_guests: true)).to match_array([developer, sub_developer])
      end
    end

    context 'with member roles' do
      let_it_be(:member_role_elevating) { create(:member_role, :billable, namespace: group) }
      let_it_be(:guest_with_role) { create(:group_member, :guest, source: group, member_role: member_role_elevating).user }

      it 'includes guests with elevating role assigned' do
        expect(group.billed_group_users(exclude_guests: true)).to match_array([developer, sub_developer, guest_with_role])
      end
    end

    context 'with banned members' do
      let_it_be(:banned) { create(:group_member, :banned, :developer, source: group).user }
      let_it_be(:sub_banned) { create(:group_member, :banned, :developer, source: sub_group).user }

      it 'excludes banned members' do
        expect(group.billed_group_users).to exclude(banned, sub_banned)
      end

      context 'when member is banned in one namespace but not another' do
        let_it_be(:another_group) { create(:group) }
        let_it_be(:banned) { create(:group_member, :banned, :developer, source: group).user }

        before do
          another_group.add_developer(banned)
        end

        it 'excludes banned member in the namespace it is banned in' do
          expect(group.billed_group_users).to exclude(banned)
        end

        it 'includes member in the namespace it isn\'t banned in' do
          expect(another_group.billed_group_users).to include(banned)
        end
      end
    end

    context 'with duplicate users across group hierarchies' do
      let_it_be(:another_sub_group) { create(:group, parent: group) }

      before_all do
        another_sub_group.add_developer(developer)
      end

      it 'returns distinct users even if they belong to multiple groups in the hierarchy' do
        expect(group.billed_group_users.count)
          .to eq(group.billed_group_users.distinct.count)
        expect(group.billed_group_users).to include(developer)
      end
    end
  end

  describe '#billed_group_members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:sub_developer) { sub_group.add_developer(create(:user)) }
    let_it_be(:guest) { group.add_guest(create(:user)) }
    let_it_be(:developer) { group.add_developer(create(:user)) }

    before_all do
      create(:group_member, :developer)
      create(:project_member, :developer, source: create(:project, namespace: group))
      create(:group_member, :invited, :developer, source: group)
      create(:group_member, :awaiting, :developer, source: group)
      create(:group_member, :minimal_access, source: group)
      create(:group_member, :access_request, :developer, source: group)
    end

    context 'with guests' do
      it 'includes members' do
        expect(group.billed_group_members).to match_array([developer, guest, sub_developer])
      end
    end

    context 'without guests' do
      it 'includes members' do
        expect(group.billed_group_members(exclude_guests: true)).to match_array([developer, sub_developer])
      end
    end

    context 'with member roles' do
      let_it_be(:member_role_elevating) { create(:member_role, :guest, :admin_vulnerability, namespace: group) }
      let_it_be(:guest_with_role) { create(:group_member, :guest, source: group, member_role: member_role_elevating) }

      it 'includes guests with elevating role assigned' do
        expect(group.billed_group_members(exclude_guests: true))
          .to match_array([developer, sub_developer, guest_with_role])
      end
    end

    context 'with banned members' do
      let_it_be(:banned) { create(:group_member, :banned, :developer, source: group) }
      let_it_be(:sub_banned) { create(:group_member, :banned, :developer, source: sub_group) }

      it 'excludes banned members' do
        expect(group.billed_group_members).to exclude(banned, sub_banned)
      end

      context 'when member is banned in one namespace but not another' do
        let_it_be(:another_group) { create(:group) }
        let_it_be(:banned_user) { create(:group_member, :banned, :developer, source: group).user }

        before_all do
          another_group.add_developer(banned_user)
        end

        it 'excludes banned member in the namespace it is banned in' do
          expect(group.billed_group_members.map(&:user)).to exclude(banned_user)
        end

        it 'includes member in the namespace it isn\'t banned in' do
          expect(another_group.billed_group_members.map(&:user)).to include(banned_user)
        end
      end
    end
  end

  describe '#billed_project_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
    let_it_be(:sub_developer) { sub_group_project.add_developer(create(:user)).user }
    let_it_be(:guest) { project.add_guest(create(:user)).user }
    let_it_be(:developer) { project.add_developer(create(:user)).user }

    before_all do
      group.add_developer(create(:user))
      project.add_developer(create(:user, :blocked))
      project.add_maintainer(create(:user, :project_bot))
      project.add_maintainer(create(:user, :alert_bot))
      project.add_maintainer(create(:user, :support_bot))
      project.add_maintainer(create(:user, :visual_review_bot))
      project.add_maintainer(create(:user, :migration_bot))
      project.add_maintainer(create(:user, :security_bot))
      project.add_maintainer(create(:user, :automation_bot))
      project.add_maintainer(create(:user, :admin_bot))
      create(:project_member, :developer)
      create(:project_member, :invited, :developer, source: project)
      create(:project_member, :awaiting, :developer, source: project)
      create(:project_member, :access_request, :developer, source: project)
    end

    context 'with guests' do
      it 'includes active users' do
        expect(group.billed_project_users).to match_array([developer, guest, sub_developer])
      end
    end

    context 'without guests' do
      it 'includes active users' do
        expect(group.billed_project_users(exclude_guests: true)).to match_array([developer, sub_developer])
      end
    end

    context 'with member roles' do
      let_it_be(:member_role_elevating) { create(:member_role, :guest, :admin_vulnerability, namespace: group) }
      let_it_be(:guest_with_role) { create(:project_member, :guest, source: project, member_role: member_role_elevating).user }

      it 'includes guests with elevating role assigned' do
        expect(group.billed_project_users(exclude_guests: true)).to match_array([developer, sub_developer, guest_with_role])
      end
    end

    context 'with banned members' do
      let_it_be(:banned) { create(:project_member, :banned, :developer, source: project).user }
      let_it_be(:sub_banned) { create(:project_member, :banned, :developer, source: sub_group_project).user }

      it 'excludes banned members' do
        expect(group.billed_project_users).to exclude(banned, sub_banned)
      end
    end

    context 'with duplicate users across projects' do
      let_it_be(:another_project) { create(:project, namespace: group) }

      before_all do
        another_project.add_developer(developer)
      end

      it 'returns distinct users even if they belong to multiple projects' do
        expect(group.billed_project_users.count)
          .to eq(group.billed_project_users.distinct.count)

        expect(group.billed_project_users).to include(developer)
      end
    end
  end

  describe '#billed_project_members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
    let_it_be(:sub_developer) { sub_group_project.add_developer(create(:user)) }
    let_it_be(:guest) { project.add_guest(create(:user)) }
    let_it_be(:developer) { project.add_developer(create(:user)) }

    before_all do
      group.add_developer(create(:user))
      create(:project_member, :developer)
      create(:project_member, :invited, :developer, source: project)
      create(:project_member, :awaiting, :developer, source: project)
      create(:project_member, :access_request, :developer, source: project)
    end

    context 'with guests' do
      it 'includes members' do
        expect(group.billed_project_members).to match_array([developer, guest, sub_developer])
      end
    end

    context 'without guests' do
      it 'includes members' do
        expect(group.billed_project_members(exclude_guests: true)).to match_array([developer, sub_developer])
      end
    end

    context 'with member roles' do
      let_it_be(:member_role_elevating) { create(:member_role, :guest, :admin_vulnerability, namespace: group) }
      let_it_be(:guest_with_role) { create(:project_member, :guest, source: project, member_role: member_role_elevating) }

      it 'includes guests with elevating role assigned' do
        expect(group.billed_project_members(exclude_guests: true))
          .to match_array([developer, sub_developer, guest_with_role])
      end
    end

    context 'with banned members' do
      let_it_be(:banned_user) { create(:project_member, :banned, :developer, source: project).user }
      let_it_be(:sub_banned_user) { create(:project_member, :banned, :developer, source: sub_group_project).user }

      it 'excludes banned members' do
        expect(group.billed_project_members.map(&:user)).to exclude(banned_user, sub_banned_user)
      end
    end
  end

  describe '#billed_shared_group_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:invited_guest_group) { create(:group) }
    let_it_be(:sub_invited_group) { create(:group) }
    let_it_be(:sub_invited_developer) { sub_invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)).user }
    let_it_be(:invited_guest_group_user) { invited_guest_group.add_developer(create(:user)).user }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)).user }

    before_all do
      group.add_developer(create(:user))
      invited_group.add_developer(create(:user, :blocked))
      invited_group.add_maintainer(create(:user, :project_bot))
      invited_group.add_maintainer(create(:user, :alert_bot))
      invited_group.add_maintainer(create(:user, :support_bot))
      invited_group.add_maintainer(create(:user, :visual_review_bot))
      invited_group.add_maintainer(create(:user, :migration_bot))
      invited_group.add_maintainer(create(:user, :security_bot))
      invited_group.add_maintainer(create(:user, :automation_bot))
      invited_group.add_maintainer(create(:user, :admin_bot))
      create(:group_member, :invited, :developer, source: invited_group)
      create(:group_member, :awaiting, :developer, source: invited_group)
      create(:group_member, :minimal_access, source: invited_group)
      create(:group_member, :access_request, :developer, source: invited_group)
      create(:group_group_link, { shared_with_group: sub_invited_group, shared_group: sub_group })
      create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
      create(:group_group_link, :guest, { shared_with_group: invited_guest_group, shared_group: group })
    end

    context 'with guests' do
      it 'includes active users from the other group' do
        expect(group.billed_shared_group_users)
          .to match_array([
            invited_guest,
            invited_developer,
            invited_guest_group_user,
            ancestor_invited_developer,
            sub_invited_developer
          ])
      end
    end

    context 'without guests' do
      it 'includes active users from the other group' do
        expect(group.billed_shared_group_users(exclude_guests: true))
          .to match_array([invited_developer, ancestor_invited_developer, sub_invited_developer])
      end
    end

    context 'with banned members' do
      let_it_be(:banned) { create(:group_member, :banned, :developer, source: group).user }
      let_it_be(:banned_invited_developer) { create(:group_member, :banned, :developer, source: invited_group).user }
      let_it_be(:sub_banned_invited_developer) { create(:group_member, :banned, :developer, source: sub_invited_group).user }

      it 'includes members that are banned in invited group' do
        # currently, if user is banned from "invited_group", they still has access to the linked "group"
        # hence, they are counted as a billable member
        # TODO: https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/314
        expect(group.billed_shared_group_users).to include(banned_invited_developer, sub_banned_invited_developer)
      end

      it 'excludes members that are banned in group' do
        expect(group.billed_shared_group_users).to exclude(banned)
      end
    end

    context 'with duplicate users across shared groups' do
      let_it_be(:another_shared_group) { create(:group) }

      before_all do
        another_shared_group.add_developer(invited_developer)
        create(:group_group_link, { shared_with_group: another_shared_group, shared_group: group })
      end

      it 'returns distinct users even if they belong to multiple shared groups' do
        expect(group.billed_shared_group_users.count)
          .to eq(group.billed_shared_group_users.distinct.count)

        expect(group.billed_shared_group_users).to include(invited_developer)
      end
    end
  end

  describe '#billed_shared_group_members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:invited_guest_group) { create(:group) }
    let_it_be(:sub_invited_group) { create(:group) }
    let_it_be(:sub_invited_developer) { sub_invited_group.add_developer(create(:user)) }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)) }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)) }
    let_it_be(:invited_guest_group_user) { invited_guest_group.add_developer(create(:user)) }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)) }

    before_all do
      group.add_developer(create(:user))
      create(:group_member, :invited, :developer, source: invited_group)
      create(:group_member, :awaiting, :developer, source: invited_group)
      create(:group_member, :minimal_access, source: invited_group)
      create(:group_member, :access_request, :developer, source: invited_group)
      create(:group_group_link, { shared_with_group: sub_invited_group, shared_group: sub_group })
      create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
      create(:group_group_link, :guest, { shared_with_group: invited_guest_group, shared_group: group })
    end

    context 'with guests' do
      it 'includes members from the other group' do
        expect(group.billed_shared_group_members)
          .to match_array([
            invited_guest,
            invited_developer,
            invited_guest_group_user,
            ancestor_invited_developer,
            sub_invited_developer
          ])
      end
    end

    context 'without guests' do
      it 'includes members from the other group' do
        expect(group.billed_shared_group_members(exclude_guests: true))
          .to match_array([invited_developer, ancestor_invited_developer, sub_invited_developer])
      end
    end

    context 'with banned members' do
      let_it_be(:banned_user) { create(:group_member, :banned, :developer, source: group).user }
      let_it_be(:banned_invited_developer) { create(:group_member, :banned, :developer, source: invited_group).user }
      let_it_be(:sub_banned_invited_developer) do
        create(:group_member, :banned, :developer, source: sub_invited_group).user
      end

      it 'includes members that are banned in invited group' do
        # currently, if user is banned from "invited_group", they still has access to the linked "group"
        # hence, they are counted as a billable member
        # TODO: https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/314
        expect(group.billed_shared_group_members.map(&:user))
          .to include(banned_invited_developer, sub_banned_invited_developer)
      end

      it 'excludes members that are banned in group' do
        expect(group.billed_shared_group_members.map(&:user)).to exclude(banned_user)
      end
    end

    context 'with member roles' do
      let_it_be(:group) { create(:group) }
      let_it_be(:invited_group) { create(:group) }

      let_it_be(:guest_elevated) { create(:member_role, :guest, :read_vulnerability) }
      let_it_be(:guest_basic) { create(:member_role, :guest, :read_code) }
      let_it_be(:developer_lead) { create(:member_role, :developer, :admin_vulnerability) }

      let_it_be(:member_a) { create(:group_member, :guest, source: invited_group) }
      let_it_be(:member_b) { create(:group_member, :guest, source: invited_group, member_role: guest_elevated) }
      let_it_be(:member_c) { create(:group_member, :guest, source: invited_group, member_role: guest_basic) }
      let_it_be(:member_d) { create(:group_member, :developer, source: invited_group) }
      let_it_be(:member_e) { create(:group_member, :developer, source: invited_group, member_role: developer_lead) }

      let_it_be(:invited_access_level) { :guest }
      let_it_be(:invited_member_role) { nil }

      before do
        create(
          :group_group_link,
          invited_access_level,
          shared_with_group: invited_group,
          shared_group: group,
          member_role: invited_member_role
        )
      end

      shared_examples 'returns all members of the invited group' do
        it do
          expect(group.billed_shared_group_members)
            .to match_array([member_a, member_b, member_c, member_d, member_e])
        end
      end

      shared_examples 'returns empty array' do
        it do
          expect(group.billed_shared_group_members(exclude_guests: true)).to be_empty
        end
      end

      shared_examples 'returns elevated guests from invited group' do
        it do
          expect(group.billed_shared_group_members(exclude_guests: true)).to match_array([member_b])
        end
      end

      shared_examples 'returns non-guests and elevated guests from invited group' do
        it do
          expect(group.billed_shared_group_members(exclude_guests: true)).to match_array([member_b, member_d, member_e])
        end
      end

      shared_examples 'returns non-guests from invited group' do
        it do
          expect(group.billed_shared_group_members(exclude_guests: true)).to match_array([member_d, member_e])
        end
      end

      context 'when group link is assigned a guest role' do
        let(:invited_access_level) { :guest }
        let(:invited_member_role) { nil }

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is enabled' do
          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns empty array'
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
          end

          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns empty array'
          end
        end
      end

      context 'when group link is assigned a guest member role that does not occupy a seat' do
        let(:invited_access_level) { :guest }
        let(:invited_member_role) { guest_basic }

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is enabled' do
          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns elevated guests from invited group'
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
          end

          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns empty array'
          end
        end
      end

      context 'when group link is assigned a guest member role that occupies a seat' do
        let(:invited_access_level) { :guest }
        let(:invited_member_role) { guest_elevated }

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is enabled' do
          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns elevated guests from invited group'
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
          end

          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns empty array'
          end
        end
      end

      context 'when group link is assigned a non-guest role' do
        let(:invited_access_level) { :developer }
        let(:invited_member_role) { nil }

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is enabled' do
          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns non-guests and elevated guests from invited group'
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
          end

          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns non-guests from invited group'
          end
        end
      end

      context 'when group link is assigned a non-guest custom role' do
        let(:invited_access_level) { :developer }
        let(:invited_member_role) { developer_lead }

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is enabled' do
          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns non-guests and elevated guests from invited group'
          end
        end

        context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
          before do
            stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
          end

          context 'with guests' do
            it_behaves_like 'returns all members of the invited group'
          end

          context 'without guests' do
            it_behaves_like 'returns non-guests from invited group'
          end
        end
      end
    end
  end

  describe '#billed_invited_group_to_project_users' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:invited_guest_group) { create(:group) }
    let_it_be(:sub_invited_group) { create(:group) }
    let_it_be(:sub_invited_developer) { sub_invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)).user }
    let_it_be(:invited_guest_group_user) { invited_guest_group.add_developer(create(:user)).user }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)).user }

    before_all do
      group.add_developer(create(:user))
      invited_group.add_developer(create(:user, :blocked))
      invited_group.add_maintainer(create(:user, :project_bot))
      invited_group.add_maintainer(create(:user, :alert_bot))
      invited_group.add_maintainer(create(:user, :support_bot))
      invited_group.add_maintainer(create(:user, :visual_review_bot))
      invited_group.add_maintainer(create(:user, :migration_bot))
      invited_group.add_maintainer(create(:user, :security_bot))
      invited_group.add_maintainer(create(:user, :automation_bot))
      invited_group.add_maintainer(create(:user, :admin_bot))
      create(:group_member, :invited, :developer, source: invited_group)
      create(:group_member, :awaiting, :developer, source: invited_group)
      create(:group_member, :minimal_access, source: invited_group)
      create(:group_member, :access_request, :developer, source: invited_group)
      create(:project_group_link)
      create(:project_group_link, project: project, group: invited_group)
      create(:project_group_link, project: sub_group_project, group: sub_invited_group)
      create(:project_group_link, :guest, project: project, group: invited_guest_group)
    end

    context 'with guests' do
      it 'includes active users from the other group' do
        expect(group.billed_invited_group_to_project_users)
          .to match_array([
            invited_guest,
            invited_developer,
            invited_guest_group_user,
            ancestor_invited_developer,
            sub_invited_developer
          ])
      end
    end

    context 'without guests' do
      it 'includes active users from the other group' do
        expect(group.billed_invited_group_to_project_users(exclude_guests: true))
          .to match_array([invited_developer, ancestor_invited_developer, sub_invited_developer])
      end
    end

    context 'with banned members' do
      let_it_be(:banned) { create(:project_member, :banned, :developer, source: project).user }
      let_it_be(:banned_invited_developer) { create(:group_member, :banned, :developer, source: invited_group).user }
      let_it_be(:sub_banned_invited_developer) { create(:group_member, :banned, :developer, source: sub_invited_group).user }

      it 'includes members that are banned in invited group' do
        # currently, if user is banned from "invited_group", they still has access to the linked "project"
        # hence, they are counted as a billable member
        # TODO: https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/314
        expect(group.billed_invited_group_to_project_users).to include(banned_invited_developer, sub_banned_invited_developer)
      end

      it 'excludes members that are banned in group' do
        expect(group.billed_invited_group_to_project_users).to exclude(banned)
      end
    end

    context 'with duplicate users across invited groups' do
      let_it_be(:another_invited_group) { create(:group) }

      before_all do
        another_invited_group.add_developer(invited_developer)
        create(:project_group_link, project: project, group: another_invited_group)
      end

      it 'returns distinct users even if they belong to multiple invited groups' do
        expect(group.billed_invited_group_to_project_users.count)
          .to eq(group.billed_invited_group_to_project_users.distinct.count)

        expect(group.billed_invited_group_to_project_users).to include(invited_developer)
      end
    end
  end

  describe '#billed_invited_group_to_project_members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:invited_guest_group) { create(:group) }
    let_it_be(:sub_invited_group) { create(:group) }
    let_it_be(:sub_invited_developer) { sub_invited_group.add_developer(create(:user)) }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)) }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)) }
    let_it_be(:invited_guest_group_user) { invited_guest_group.add_developer(create(:user)) }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)) }

    before_all do
      group.add_developer(create(:user))
      create(:group_member, :invited, :developer, source: invited_group)
      create(:group_member, :awaiting, :developer, source: invited_group)
      create(:group_member, :minimal_access, source: invited_group)
      create(:group_member, :access_request, :developer, source: invited_group)
      create(:project_group_link)
      create(:project_group_link, project: project, group: invited_group)
      create(:project_group_link, project: sub_group_project, group: sub_invited_group)
      create(:project_group_link, :guest, project: project, group: invited_guest_group)
    end

    context 'with guests' do
      it 'includes members from the other group' do
        expect(group.billed_invited_group_to_project_members)
          .to match_array([
            invited_guest,
            invited_developer,
            invited_guest_group_user,
            ancestor_invited_developer,
            sub_invited_developer
          ])
      end
    end

    context 'without guests' do
      it 'includes members from the other group' do
        expect(group.billed_invited_group_to_project_members(exclude_guests: true))
          .to match_array([invited_developer, ancestor_invited_developer, sub_invited_developer])
      end
    end

    context 'with banned members' do
      let_it_be(:banned_user) { create(:project_member, :banned, :developer, source: project).user }
      let_it_be(:banned_invited_developer) { create(:group_member, :banned, :developer, source: invited_group).user }
      let_it_be(:sub_banned_invited_developer) do
        create(:group_member, :banned, :developer, source: sub_invited_group).user
      end

      it 'includes members that are banned in invited group' do
        # currently, if user is banned from "invited_group", they still has access to the linked "project"
        # hence, they are counted as a billable member
        # TODO: https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/314
        expect(group.billed_invited_group_to_project_members.map(&:user))
          .to include(banned_invited_developer, sub_banned_invited_developer)
      end

      it 'excludes members that are banned in group' do
        expect(group.billed_invited_group_to_project_members.map(&:user)).to exclude(banned_user)
      end
    end
  end

  describe '#billed_users_from_members' do
    let_it_be(:group) { create(:group) }
    let_it_be(:guest) { group.add_guest(create(:user)) }
    let_it_be(:developer) { group.add_developer(create(:user)) }
    let_it_be(:blocked_member) { group.add_developer(create(:user, :blocked)) }
    let(:members) { Member.id_in([guest, developer, blocked_member]) }

    before_all do
      group.add_maintainer(create(:user, :project_bot))
      group.add_maintainer(create(:user, :alert_bot))
      group.add_maintainer(create(:user, :support_bot))
      group.add_maintainer(create(:user, :visual_review_bot))
      group.add_maintainer(create(:user, :migration_bot))
      group.add_maintainer(create(:user, :security_bot))
      group.add_maintainer(create(:user, :automation_bot))
      group.add_maintainer(create(:user, :admin_bot))
    end

    it 'provides users without bots' do
      expect(group.billed_users_from_members(members)).to match_array(members.map(&:user))
    end

    context 'when another merge_condition is added' do
      it 'provides users without bots' do
        expect(group.billed_users_from_members(members, merge_condition: ::User.with_state(:active)))
          .to match_array([guest, developer].map(&:user))
      end
    end
  end

  describe '#billed_group_user?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:developer) { group.add_developer(create(:user)).user }
    let_it_be(:sub_developer) { sub_group.add_developer(create(:user)).user }
    let_it_be(:guest) { group.add_guest(create(:user)).user }

    where(:user, :exclude_guests, :result) do
      ref(:developer)     | false | true
      ref(:sub_developer) | false | true
      ref(:guest)         | false | true
      ref(:developer)     | true  | true
      ref(:sub_developer) | true  | true
      ref(:guest)         | true  | false
    end

    subject { group.billed_group_user?(user, exclude_guests: exclude_guests) }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#billed_project_user?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:sub_group_project) { create(:project, namespace: create(:group, parent: group)) }
    let_it_be(:developer) { project.add_developer(create(:user)).user }
    let_it_be(:sub_developer) { sub_group_project.add_developer(create(:user)).user }
    let_it_be(:guest) { project.add_guest(create(:user)).user }

    where(:user, :exclude_guests, :result) do
      ref(:developer)     | false | true
      ref(:sub_developer) | false | true
      ref(:guest)         | false | true
      ref(:developer)     | true  | true
      ref(:sub_developer) | true  | true
      ref(:guest)         | true  | false
    end

    subject { group.billed_project_user?(user, exclude_guests: exclude_guests) }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#billed_shared_group_user?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)).user }

    before_all do
      create(:group_group_link, { shared_with_group: invited_group, shared_group: group })
    end

    where(:user, :exclude_guests, :result) do
      ref(:ancestor_invited_developer) | false | true
      ref(:invited_developer)          | false | true
      ref(:invited_guest)              | false | true
      ref(:ancestor_invited_developer) | true  | true
      ref(:invited_developer)          | true  | true
      ref(:invited_guest)              | true  | false
    end

    subject { group.billed_shared_group_user?(user, exclude_guests: exclude_guests) }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#billed_shared_project_user?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:ancestor_invited_group) { create(:group) }
    let_it_be(:invited_group) { create(:group, parent: ancestor_invited_group) }
    let_it_be(:ancestor_invited_developer) { ancestor_invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_developer) { invited_group.add_developer(create(:user)).user }
    let_it_be(:invited_guest) { invited_group.add_guest(create(:user)).user }

    before_all do
      create(:project_group_link, project: project, group: invited_group)
    end

    where(:user, :exclude_guests, :result) do
      ref(:ancestor_invited_developer) | false | true
      ref(:invited_developer)          | false | true
      ref(:invited_guest)              | false | true
      ref(:ancestor_invited_developer) | true  | true
      ref(:invited_developer)          | true  | true
      ref(:invited_guest)              | true  | false
    end

    subject { group.billed_shared_project_user?(user, exclude_guests: exclude_guests) }

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#assigning_role_too_high?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:member, reload: true) { create(:group_member, :reporter, group: group, user: user) }

    subject(:assigning_role_too_high) { group.assigning_role_too_high?(user, access_level) }

    context 'when the access_level is nil' do
      let(:access_level) { nil }

      it 'returns false' do
        expect(assigning_role_too_high).to be_falsey
      end
    end

    context 'when the role being assigned is lower then the role of currect user' do
      let(:access_level) { Gitlab::Access::GUEST }

      it { is_expected.to be(false) }
    end

    context 'when the role being assigned is equal to the role of currect user' do
      let(:access_level) { Gitlab::Access::REPORTER }

      it { is_expected.to be(false) }
    end

    context 'when the role being assigned is higher than the role of currect user' do
      let(:access_level) { Gitlab::Access::MAINTAINER }

      it 'returns true' do
        expect(assigning_role_too_high).to be_truthy
      end

      context 'when the current user is admin', :enable_admin_mode do
        before do
          user.update!(admin: true)
        end

        it 'returns false' do
          expect(assigning_role_too_high).to be_falsey
        end
      end
    end
  end

  describe '#eligible_for_gitlab_duo_pro_seat?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, namespace: sub_group) }
    let_it_be(:user) { create(:user) }

    let(:subject) { group.eligible_for_gitlab_duo_pro_seat?(user) }

    context 'when the user has non-minimal access via group' do
      before do
        sub_group.add_guest(user)
      end

      it { is_expected.to be true }
    end

    context 'when the user has non-minimal access via project' do
      before do
        project.add_guest(user)
      end

      it { is_expected.to be true }
    end

    context 'with group invite' do
      let_it_be(:invited_group) { create(:group) }

      before do
        invited_group.add_guest(user)
      end

      context 'when the user has non-minimal access being invited to a group' do
        before do
          create(:group_group_link, shared_with_group: invited_group, shared_group: sub_group)
        end

        it { is_expected.to be true }
      end

      context 'when the user has non-minimal access being invited to a project' do
        before do
          create(:project_group_link, project: project, group: invited_group)
        end

        it { is_expected.to be true }
      end
    end

    context 'when the user has minimal access role' do
      before do
        create(:group_member, :minimal_access, user: user, source: group)
      end

      it { is_expected.to be false }
    end

    context 'when the user is not member of group' do
      it { is_expected.to be false }
    end
  end

  describe '#gitlab_duo_eligible_user_ids', :saas do
    include_context 'for billable users setup'

    subject(:eligible_user_ids) { group.gitlab_duo_eligible_user_ids }

    it 'includes distinct active users' do
      expect(eligible_user_ids).to match_array([
        group_guest.id,
        project_guest.id,
        group_developer.id,
        project_developer.id,
        invited_developer.id
      ])
    end

    it 'excludes banned members' do
      expect(eligible_user_ids).to exclude(banned_group_user.id, banned_project_user.id)
    end
  end

  describe '#capacity_left_for_user?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    where(:current_user, :user_cap_available, :user_cap_reached, :existing_membership, :result) do
      ref(:user)                | false           | false              | false               | true
      ref(:user)                | false           | false              | true                | true
      ref(:user)                | false           | true               | true                | true
      ref(:user)                | true            | false              | false               | true
      ref(:user)                | true            | false              | true                | true
      ref(:user)                | true            | true               | true                | true
      ref(:user)                | true            | true               | false               | false
      nil                       | false           | false              | false               | true
      nil                       | true            | false              | false               | true
      nil                       | true            | true               | false               | false
    end

    subject { group.capacity_left_for_user?(current_user) }

    with_them do
      before do
        create(:group_member, source: group, user: current_user) if existing_membership

        allow(group).to receive(:user_cap_available?).and_return(user_cap_available)
        allow(group).to receive(:user_cap_reached?).and_return(user_cap_reached)
      end

      it { is_expected.to eq(result) }
    end

    context 'with security_policy_bot as a member in the group project' do
      let_it_be(:group_project) { create(:project, group: group) }
      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

      where(:current_user, :user_cap_available, :user_cap_reached, :existing_membership, :result) do
        ref(:security_policy_bot) | false           | false              | false               | true
        ref(:security_policy_bot) | false           | false              | true                | true
        ref(:security_policy_bot) | false           | true               | true                | true
        ref(:security_policy_bot) | true            | false              | false               | true
        ref(:security_policy_bot) | true            | false              | true                | true
        ref(:security_policy_bot) | true            | true               | true                | true
        ref(:security_policy_bot) | true            | true               | false               | true
      end

      subject { group.capacity_left_for_user?(current_user) }

      with_them do
        before do
          create(:project_member, source: group_project, user: current_user) if existing_membership

          allow(group).to receive(:user_cap_available?).and_return(user_cap_available)
          allow(group).to receive(:user_cap_reached?).and_return(user_cap_reached)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#has_free_or_no_subscription?', :saas do
    it 'returns true with a free plan' do
      group = create(:group_with_plan, plan: :free_plan)

      expect(group.has_free_or_no_subscription?).to be(true)
    end

    it 'returns false when the plan is not free' do
      group = create(:group_with_plan, plan: :ultimate_plan)

      expect(group.has_free_or_no_subscription?).to be(false)
    end

    it 'returns true when there is no plan' do
      group = create(:group)

      expect(group.has_free_or_no_subscription?).to be(true)
    end

    it 'returns true when there is a subscription with no plan' do
      group = create(:group)
      create(:gitlab_subscription, hosted_plan: nil, namespace: group)

      expect(group.has_free_or_no_subscription?).to be(true)
    end

    context 'when it is a subgroup' do
      let(:subgroup) { create(:group, parent: group) }

      context 'with a free plan' do
        let(:group) { create(:group_with_plan, plan: :free_plan) }

        it 'returns true' do
          expect(subgroup.has_free_or_no_subscription?).to be(true)
        end
      end

      context 'with a plan that is not free' do
        let(:group) { create(:group_with_plan, plan: :ultimate_plan) }

        it 'returns false' do
          expect(subgroup.has_free_or_no_subscription?).to be(false)
        end
      end

      context 'when there is no plan' do
        let(:group) { create(:group) }

        it 'returns true' do
          expect(subgroup.has_free_or_no_subscription?).to be(true)
        end
      end

      context 'when there is a subscription with no plan' do
        let(:group) { create(:group) }

        before do
          create(:gitlab_subscription, hosted_plan: nil, namespace: group)
        end

        it 'returns true' do
          expect(subgroup.has_free_or_no_subscription?).to be(true)
        end
      end
    end
  end

  describe '#enforce_free_user_cap?' do
    let(:group) { build(:group) }

    where(:enforce_free_cap, :result) do
      false | false
      true  | true
    end

    subject { group.enforce_free_user_cap? }

    with_them do
      specify do
        expect_next_instance_of(Namespaces::FreeUserCap::Enforcement, group) do |instance|
          expect(instance).to receive(:enforce_cap?).and_return(enforce_free_cap)
        end

        is_expected.to eq(result)
      end
    end
  end

  describe '#exclude_guests?', :saas do
    let_it_be(:group, refind: true) { create(:group) }

    where(:actual_plan_name, :requested_plan_name, :result) do
      :free                         | nil        | false
      :premium                      | nil        | false
      :ultimate                     | nil        | true
      :ultimate_trial               | nil        | true
      :ultimate_trial_paid_customer | nil        | false
      :gold                         | nil        | true

      :free           | 'premium'  | false
      :free           | 'ultimate' | true
      :premium        | 'ultimate' | true
      :ultimate       | 'ultimate' | true
    end

    with_them do
      let!(:subscription) { build(:gitlab_subscription, actual_plan_name, namespace: group) }

      it 'returns the expected result' do
        expect(group.exclude_guests?(requested_plan_name)).to eq(result)
      end
    end
  end

  describe '#actual_plan_name', :saas do
    let_it_be(:parent) { create(:group) }
    let_it_be(:subgroup, refind: true) { create(:group, parent: parent) }

    subject(:actual_plan_name) { subgroup.actual_plan_name }

    context 'when parent group has a subscription associated' do
      before do
        create(:gitlab_subscription, :ultimate, namespace: parent)
      end

      it 'returns an associated plan name' do
        expect(actual_plan_name).to eq 'ultimate'
      end
    end

    context 'when parent group does not have subscription associated' do
      it 'returns a free plan name' do
        expect(actual_plan_name).to eq 'free'
      end
    end
  end

  describe '#users_count' do
    subject { group.users_count }

    let(:group) { create(:group) }
    let(:user) { create(:user) }

    context 'with `minimal_access_role` not licensed' do
      before do
        stub_licensed_features(minimal_access_role: false)
        create(:group_member, :minimal_access, user: user, source: group)
      end

      it 'does not count the minimal access user' do
        expect(group.users_count).to eq(0)
      end
    end

    context 'with `minimal_access_role` licensed' do
      before do
        stub_licensed_features(minimal_access_role: true)
        create(:group_member, :minimal_access, user: user, source: group)
      end

      it 'counts the minimal access user' do
        expect(group.users_count).to eq(1)
      end
    end
  end

  describe '#saml_discovery_token' do
    it 'returns existing tokens' do
      group = create(:group, saml_discovery_token: 'existing')

      expect(group.saml_discovery_token).to eq 'existing'
    end

    context 'when missing on read' do
      it 'generates a token' do
        expect(group.saml_discovery_token.length).to eq 8
      end

      it 'saves the generated token' do
        expect { group.saml_discovery_token }.to change { group.reload.read_attribute(:saml_discovery_token) }
      end

      context 'in read-only mode' do
        before do
          allow(Gitlab::Database).to receive(:read_only?).and_return(true)
          allow(group).to receive(:create_or_update).and_raise(ActiveRecord::ReadOnlyRecord)
        end

        it "doesn't raise an error as that could expose group existence" do
          expect { group.saml_discovery_token }.not_to raise_error
        end

        it 'returns a random value to prevent access' do
          expect(group.saml_discovery_token).not_to be_blank
        end
      end
    end
  end

  describe '#saml_enabled?' do
    subject { group.saml_enabled? }

    context 'when a SAML provider does not exist' do
      it { is_expected.to eq(false) }
    end

    context 'when a SAML provider exists and is persisted' do
      before do
        create(:saml_provider, group: group)
      end

      it { is_expected.to eq(true) }
    end

    context 'when a SAML provider is not persisted' do
      before do
        build(:saml_provider, group: group)
      end

      it { is_expected.to eq(false) }
    end

    context 'when global SAML is enabled' do
      before do
        stub_basic_saml_config
      end

      it { is_expected.to eq(true) }
    end
  end

  describe '#saml_group_sync_available?' do
    subject { group.saml_group_sync_available? }

    it { is_expected.to eq(false) }

    context 'with group_saml_group_sync feature licensed' do
      before do
        stub_licensed_features(saml_group_sync: true)
      end

      it { is_expected.to eq(false) }

      context 'with saml enabled' do
        before do
          create(:saml_provider, group: group, enabled: true)
        end

        it { is_expected.to eq(true) }

        context 'when the group is a subgroup' do
          let(:subgroup) { create(:group, :private, parent: group) }

          subject { subgroup.saml_group_sync_available? }

          it { is_expected.to eq(true) }
        end
      end
    end
  end

  describe '#saml_group_links_exists?' do
    subject { group.saml_group_links_exists? }

    context 'with group saml disabled' do
      it { is_expected.to eq(false) }
    end

    context 'with group saml enabled' do
      before do
        create(:saml_provider, group: group)
      end

      context "without saml group links" do
        it { is_expected.to eq(false) }
      end

      context 'with saml group links' do
        before do
          create(:saml_group_link, group: group)
        end

        it { is_expected.to eq(true) }
      end
    end
  end

  describe "#insights_config" do
    context 'when group has no Insights project configured' do
      it 'returns the default config' do
        expect(group.insights_config).to eq(group.default_insights_config)
      end
    end

    context 'when group has an Insights project configured without a config file' do
      before do
        project = create(:project, group: group)
        group.create_insight!(project: project)
      end

      it 'returns the default config' do
        expect(group.insights_config).to eq(group.default_insights_config)
      end
    end

    context 'when group has an Insights project configured' do
      before do
        project = create(:project, :custom_repo, group: group, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => insights_file_content })
        group.create_insight!(project: project)
      end

      context 'with a valid config file' do
        let(:insights_file_content) { 'key: monthlyBugsCreated' }

        it 'returns the insights config data' do
          insights_config = group.insights_config

          expect(insights_config).to eq(key: 'monthlyBugsCreated')
        end
      end

      context 'with an invalid config file' do
        let(:insights_file_content) { ': foo bar' }

        it 'returns nil' do
          expect(group.insights_config).to be_nil
        end
      end
    end

    context 'when group has an Insights project configured which is in a nested group' do
      before do
        nested_group = create(:group, parent: group)
        project = create(:project, :custom_repo, group: nested_group, files: { ::Gitlab::Insights::CONFIG_FILE_PATH => insights_file_content })
        group.create_insight!(project: project)
      end

      let(:insights_file_content) { 'key: monthlyBugsCreated' }

      it 'returns the insights config data' do
        insights_config = group.insights_config

        expect(insights_config).to eq(key: 'monthlyBugsCreated')
      end
    end
  end

  describe '#any_hook_failed?' do
    let_it_be(:group) { create(:group) }

    subject { group.any_hook_failed? }

    it { is_expected.to eq(false) }
  end

  describe "#execute_hooks" do
    context "group_webhooks", :request_store do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent_group) }
      let_it_be(:group_hook) { create(:group_hook, group: group, member_events: true) }
      let_it_be(:parent_group_hook) { create(:group_hook, group: parent_group, member_events: true) }

      let(:data) { { some: 'info' } }

      shared_examples 'enabled group hooks' do
        context 'execution' do
          it 'executes the hook for self and ancestor groups by default' do
            expect(WebHookService)
              .to receive(:new)
              .with(group_hook, data, 'member_hooks', idempotency_key: anything)
              .and_call_original
            expect(WebHookService)
              .to receive(:new)
              .with(parent_group_hook, data, 'member_hooks', idempotency_key: anything)
              .and_call_original

            group.execute_hooks(data, :member_hooks)
          end
        end
      end

      context 'when group_webhooks feature is enabled through license' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        it_behaves_like 'enabled group hooks'
      end

      context 'when group_webhooks feature is enabled through usage ping features' do
        before do
          stub_usage_ping_features(true)
          allow(License).to receive(:current).and_return(nil)
        end

        it_behaves_like 'enabled group hooks'
      end

      context 'when group_webhooks feature is disabled' do
        before do
          stub_licensed_features(group_webhooks: false)
        end

        it 'does not execute the hook' do
          expect(WebHookService).not_to receive(:new)

          group.execute_hooks(data, :member_hooks)
        end
      end
    end
  end

  context 'subgroup hooks', :sidekiq_inline do
    let_it_be(:grandparent_group) { create(:group) }
    let_it_be(:parent_group) { create(:group, parent: grandparent_group) }
    let_it_be_with_refind(:subgroup) { create(:group, parent: parent_group) }
    let_it_be(:parent_group_hook) { create(:group_hook, group: parent_group, subgroup_events: true) }

    def webhook_body(subgroup:, parent_group:, event_name:)
      {
        created_at: subgroup.created_at.xmlschema,
        updated_at: subgroup.updated_at.xmlschema,
        name: subgroup.name,
        path: subgroup.path,
        full_path: subgroup.full_path,
        group_id: subgroup.id,
        parent_name: parent_group.name,
        parent_path: parent_group.path,
        parent_full_path: parent_group.full_path,
        parent_group_id: parent_group.id,
        event_name: event_name
      }
    end

    def webhook_headers
      {
        'Content-Type' => 'application/json',
        'User-Agent' => "GitLab/#{Gitlab::VERSION}",
        'X-Gitlab-Event' => 'Subgroup Hook'
      }
    end

    before do
      WebMock.stub_request(:post, parent_group_hook.url)
    end

    context 'when a subgroup is added to the parent group' do
      it 'executes the webhook' do
        subgroup = create(:group, parent: parent_group)

        expect(WebMock).to have_requested(:post, parent_group_hook.url).with(
          headers: webhook_headers,
          body: webhook_body(subgroup: subgroup, parent_group: parent_group, event_name: 'subgroup_create')
        )
      end
    end

    context 'when a subgroup is removed from the parent group' do
      it 'executes the webhook' do
        subgroup.destroy!

        expect(WebMock).to have_requested(:post, parent_group_hook.url).with(
          headers: webhook_headers,
          body: webhook_body(subgroup: subgroup, parent_group: parent_group, event_name: 'subgroup_destroy')
        )
      end
    end

    context 'when the subgroup has subgroup webhooks enabled' do
      let_it_be(:subgroup_hook) { create(:group_hook, group: subgroup, subgroup_events: true) }

      it 'does not execute the webhook on itself' do
        subgroup.destroy!

        expect(WebMock).not_to have_requested(:post, subgroup_hook.url)
      end
    end

    context 'ancestor groups' do
      let_it_be(:grand_parent_group_hook) { create(:group_hook, group: grandparent_group, subgroup_events: true) }

      before do
        WebMock.stub_request(:post, grand_parent_group_hook.url)
      end

      it 'fires webhook twice when both parent & grandparent group has subgroup_events enabled' do
        subgroup.destroy!

        expect(WebMock).to have_requested(:post, grand_parent_group_hook.url)
        expect(WebMock).to have_requested(:post, parent_group_hook.url)
      end

      context 'when parent group does not have subgroup_events enabled' do
        before do
          parent_group_hook.update!(subgroup_events: false)
        end

        it 'fires webhook once for the grandparent group when it has subgroup_events enabled' do
          subgroup.destroy!

          expect(WebMock).to have_requested(:post, grand_parent_group_hook.url)
          expect(WebMock).not_to have_requested(:post, parent_group_hook.url)
        end
      end
    end

    context 'when the group is not a subgroup' do
      let_it_be(:grand_parent_group_hook) { create(:group_hook, group: grandparent_group, subgroup_events: true) }

      it 'does not proceed to firing any webhooks' do
        allow(grandparent_group).to receive(:execute_hooks)

        expect { grandparent_group.destroy! }.to raise_error(ActiveRecord::InvalidForeignKey)

        expect(grandparent_group).not_to have_received(:execute_hooks)
      end
    end

    context 'when group webhooks are unlicensed' do
      before do
        stub_licensed_features(group_webhooks: false)
      end

      it 'does not execute the webhook' do
        subgroup.destroy!

        expect(WebMock).not_to have_requested(:post, parent_group_hook.url)
      end
    end
  end

  context 'when resource access token hooks for expiry notification' do
    let(:group) { create(:group) }
    let(:group_hook) { create(:group_hook, group: group, resource_access_token_events: true) }

    before do
      stub_licensed_features(group_webhooks: true)
    end

    context 'when interval is seven days' do
      let(:data) { { interval: :seven_days } }

      it 'executes webhook' do
        expect(WebHookService)
          .to receive(:new)
          .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
          .and_call_original

        group.execute_hooks(data, :resource_access_token_hooks)
      end
    end

    describe '#disable_personal_access_tokens?' do
      before do
        group.update!(disable_personal_access_tokens: true)
      end

      context 'when not licensed' do
        it 'returns false even if the database value is true' do
          expect(group.disable_personal_access_tokens?).to be_falsey
        end
      end

      context 'when licensed' do
        before do
          stub_licensed_features(disable_personal_access_tokens: true)
        end

        it 'returns false even if the database value is true' do
          expect(group.disable_personal_access_tokens?).to be_falsey
        end

        context 'on SaaS', :saas do
          before do
            stub_saas_features(disable_personal_access_tokens: true)
          end

          it 'returns true' do
            expect(group.disable_personal_access_tokens?).to be_truthy
          end

          context 'for a subgroup' do
            let(:subgroup) { create(:group, parent: group) }

            it 'returns false even if the database value is true' do
              subgroup.update!(disable_personal_access_tokens: true)

              expect(subgroup.disable_personal_access_tokens?).to be_falsey
            end
          end
        end
      end
    end

    context 'when setting extended_grat_expiry_webhooks_execute is disabled' do
      before do
        group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: false)
      end

      context 'when interval is thirty days' do
        let(:data) { { interval: :thirty_days } }

        it 'does not execute the hook' do
          expect(WebHookService).not_to receive(:new)

          group.execute_hooks(data, :resource_access_token_hooks)
        end
      end

      context 'when interval is sixty days' do
        let(:data) { { interval: :sixty_days } }

        it 'does not execute the hook' do
          expect(WebHookService).not_to receive(:new)

          group.execute_hooks(data, :resource_access_token_hooks)
        end
      end
    end

    context 'when setting extended_grat_expiry_webhooks_execute is enabled' do
      before do
        group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: true)
      end

      context 'when interval is thirty days' do
        let(:data) { { interval: :thirty_days } }

        it 'executes webhook' do
          expect(WebHookService)
            .to receive(:new)
            .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
            .and_call_original

          group.execute_hooks(data, :resource_access_token_hooks)
        end
      end

      context 'when interval is sixty days' do
        let(:data) { { interval: :sixty_days } }

        it 'executes webhook' do
          expect(WebHookService)
            .to receive(:new)
            .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
            .and_call_original

          group.execute_hooks(data, :resource_access_token_hooks)
        end
      end
    end

    context 'when group has subgroup with same webhook configured' do
      let(:subgroup) { create(:group, parent: group) }
      let(:subgroup_hook) { create(:group_hook, group: subgroup, resource_access_token_events: true) }
      let(:data) { { interval: :thirty_days } }

      context 'when setting extended_grat_expiry_webhooks_execute is disabled for parent group' do
        before do
          group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: false)
        end

        context 'when subgroup setting is enabled' do
          before do
            subgroup.namespace_settings.update!(extended_grat_expiry_webhooks_execute: true)
          end

          it 'executes webhook for subgroup and not parent group' do
            expect(WebHookService)
              .to receive(:new)
              .with(subgroup_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            expect(WebHookService)
              .not_to receive(:new)
              .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            subgroup.execute_hooks(data, :resource_access_token_hooks)
          end
        end

        context 'when subgroup setting is disabled' do
          before do
            subgroup.namespace_settings.update!(extended_grat_expiry_webhooks_execute: false)
          end

          it 'does not execute webhook for subgroup and not parent group' do
            expect(WebHookService).not_to receive(:new)

            subgroup.execute_hooks(data, :resource_access_token_hooks)
          end
        end
      end

      context 'when setting extended_grat_expiry_webhooks_execute is enabled for parent group' do
        before do
          group.namespace_settings.update!(extended_grat_expiry_webhooks_execute: true)
        end

        context 'when subgroup setting is enabled' do
          before do
            subgroup.namespace_settings.update!(extended_grat_expiry_webhooks_execute: true)
          end

          it 'executes webhook both for subgroup and parent group' do
            expect(WebHookService)
              .to receive(:new)
              .with(subgroup_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            expect(WebHookService)
              .to receive(:new)
              .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            subgroup.execute_hooks(data, :resource_access_token_hooks)
          end
        end

        context 'when subgroup setting is disabled' do
          before do
            subgroup.namespace_settings.update!(extended_grat_expiry_webhooks_execute: false)
          end

          it 'does not execute webhook for subgroup, but does execute for parent group' do
            expect(WebHookService)
              .not_to receive(:new)
              .with(subgroup_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            expect(WebHookService)
              .to receive(:new)
              .with(group_hook, data, 'resource_access_token_hooks', idempotency_key: anything)
              .and_call_original

            subgroup.execute_hooks(data, :resource_access_token_hooks)
          end
        end
      end
    end
  end

  describe '#personal_access_token_expiration_policy_available?' do
    subject { group.personal_access_token_expiration_policy_available? }

    let(:group) { build(:group) }

    context 'when the group does not enforce managed accounts' do
      it { is_expected.to be_falsey }
    end

    context 'when the group enforces managed accounts' do
      before do
        allow(group).to receive(:enforced_group_managed_accounts?).and_return(true)
      end

      context 'with `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        it { is_expected.to be_truthy }
      end

      context 'with `personal_access_token_expiration_policy` not licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#update_personal_access_tokens_lifetime' do
    subject { group.update_personal_access_tokens_lifetime }

    let(:limit) { 1 }
    let(:group) { build(:group, max_personal_access_token_lifetime: limit) }

    shared_examples_for 'it does not call the update lifetime service' do
      it 'doesn not call the update lifetime service' do
        expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

        subject
      end
    end

    context 'when the group does not enforce managed accounts' do
      it_behaves_like 'it does not call the update lifetime service'
    end

    context 'when the group enforces managed accounts' do
      before do
        allow(group).to receive(:enforced_group_managed_accounts?).and_return(true)
      end

      context 'with `personal_access_token_expiration_policy` not licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it_behaves_like 'it does not call the update lifetime service'
      end

      context 'with `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when the group does not enforce a PAT expiry policy' do
          let(:limit) { nil }

          it_behaves_like 'it does not call the update lifetime service'
        end

        context 'when the group enforces a PAT expiry policy' do
          it 'executes the update lifetime service' do
            expect_next_instance_of(::PersonalAccessTokens::Groups::UpdateLifetimeService, group) do |service|
              expect(service).to receive(:execute)
            end

            subject
          end
        end
      end
    end
  end

  describe '#max_personal_access_token_lifetime_from_now' do
    subject { group.max_personal_access_token_lifetime_from_now }

    let(:days_from_now) { nil }
    let(:group) { build(:group, max_personal_access_token_lifetime: days_from_now) }

    context 'when max_personal_access_token_lifetime is defined' do
      let(:days_from_now) { 30 }

      it 'is a date' do
        expect(subject).to be_a Date
      end

      it 'is in the future' do
        expect(subject).to be_future
      end

      it 'is in days_from_now' do
        expect(subject.to_date - Date.today).to eq days_from_now
      end
    end

    context 'when max_personal_access_token_lifetime is nil' do
      it 'is nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#owners_emails' do
    let(:user) { create(:user, email: 'bob@example.com') }

    before do
      group.add_owner(user)
    end

    subject { group.owners_emails }

    it { is_expected.to match([user.email]) }
  end

  describe "#access_level_roles" do
    let(:group) { create(:group) }

    before do
      stub_licensed_features(minimal_access_role: true)
    end

    it "returns the correct roles" do
      expect(group.access_level_roles).to eq(
        {
          "Minimal Access" => 5,
          "Guest" => 10,
          "Planner" => 15,
          "Reporter" => 20,
          "Developer" => 30,
          "Maintainer" => 40,
          "Owner" => 50
        }
      )
    end
  end

  describe 'Releases Stats' do
    context 'when there are no releases' do
      describe '#releases_count' do
        it 'returns 0' do
          expect(group.releases_count).to eq(0)
        end
      end

      describe '#releases_percentage' do
        it 'returns 0 and does not attempt to divide by 0' do
          expect(group.releases_percentage).to eq(0)
        end
      end
    end

    context 'when there are some releases' do
      before do
        subgroup_1 = create(:group, parent: group)
        subgroup_2 = create(:group, parent: subgroup_1)

        project_in_group = create(:project, group: group)
        _project_in_subgroup_1 = create(:project, group: subgroup_1)
        project_in_subgroup_2 = create(:project, group: subgroup_2)
        project_in_unrelated_group = create(:project)

        create(:release, project: project_in_group)
        create(:release, project: project_in_subgroup_2)
        create(:release, project: project_in_unrelated_group)
      end

      describe '#releases_count' do
        it 'counts all releases for group and descendants' do
          expect(group.releases_count).to eq(2)
        end
      end

      describe '#releases_percentage' do
        it 'calculates projects with releases percentage for group and descendants' do
          # 2 out of 3 projects have releases
          expect(group.releases_percentage).to eq(67)
        end
      end
    end
  end

  describe '#repository_storage', :aggregate_failures do
    context 'when wiki does not have a tracked repository storage' do
      it 'returns the default shard' do
        expect(::Repository).to receive(:pick_storage_shard).and_call_original
        expect(subject.repository_storage).to eq('default')
      end
    end

    context 'when wiki has a tracked repository storage' do
      it 'returns the persisted shard' do
        group.wiki.create_wiki_repository

        expect(group.group_wiki_repository).to receive(:shard_name).and_return('foo')

        expect(group.repository_storage).to eq('foo')
      end
    end
  end

  describe '#user_cap_reached?' do
    subject(:user_cap_reached_for_group?) { group.user_cap_reached? }

    context 'when user cap feature is not available' do
      before do
        allow(group).to receive(:user_cap_available?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when user cap feature is available' do
      before do
        allow(group).to receive(:user_cap_available?).and_return(true)
      end

      let(:seat_control) { :off }
      let(:new_user_signups_cap) { nil }

      shared_examples 'returning the right value for user_cap_reached?' do
        before do
          allow(root_group).to receive(:user_cap_available?).and_return(true)
          root_group.namespace_settings.update!(seat_control: seat_control, new_user_signups_cap: new_user_signups_cap)
        end

        context 'when no user cap has been set to that root ancestor' do
          it { is_expected.to be_falsey }
        end

        context 'when a user cap has been set to that root ancestor' do
          let(:seat_control) { :user_cap }
          let(:new_user_signups_cap) { 100 }

          before do
            allow(root_group).to receive(:billable_members_count).and_return(billable_members_count)
            allow(group).to receive(:root_ancestor).and_return(root_group)
          end

          context 'when this cap is higher than the number of billable members' do
            let(:billable_members_count) { new_user_signups_cap - 10 }

            it { is_expected.to be_falsey }
          end

          context 'when this cap is the same as the number of billable members' do
            let(:billable_members_count) { new_user_signups_cap }

            it { is_expected.to be_truthy }
          end

          context 'when this cap is lower than the number of billable members' do
            let(:billable_members_count) { new_user_signups_cap + 10 }

            it { is_expected.to be_truthy }
          end
        end
      end

      context 'when this group has no root ancestor' do
        it_behaves_like 'returning the right value for user_cap_reached?' do
          let(:root_group) { group }
        end
      end

      context 'when this group has a root ancestor' do
        it_behaves_like 'returning the right value for user_cap_reached?' do
          let(:root_group) { create(:group, children: [group]) }
        end
      end
    end
  end

  describe '#calculate_reactive_cache' do
    let(:group) { build(:group) }

    subject { group.calculate_reactive_cache }

    it 'returns cache data for the free plan members count' do
      expect(group).to receive(:billable_members_count).and_return(5)

      is_expected.to eq(5)
    end
  end

  describe '#shared_externally?' do
    let_it_be(:group, refind: true) { create(:group) }
    let_it_be(:subgroup_1) { create(:group, parent: group) }
    let_it_be(:subgroup_2) { create(:group, parent: group) }
    let_it_be(:external_group) { create(:group) }
    let_it_be(:project) { create(:project, group: subgroup_1) }

    subject(:shared_externally?) { group.shared_externally? }

    it 'returns false when the group is not shared outside of the namespace hierarchy' do
      expect(shared_externally?).to be false
    end

    it 'returns true when the group is shared outside of the namespace hierarchy' do
      create(:group_group_link, shared_group: group, shared_with_group: external_group)

      expect(shared_externally?).to be true
    end

    it 'returns false when the group is shared internally within the namespace hierarchy' do
      create(:group_group_link, shared_group: subgroup_1, shared_with_group: subgroup_2)

      expect(shared_externally?).to be false
    end

    it 'returns true when a subgroup is shared outside of the namespace hierarchy' do
      create(:group_group_link, shared_group: subgroup_1, shared_with_group: external_group)

      expect(shared_externally?).to be true
    end

    it 'returns false when the only shared groups are outside of the namespace hierarchy' do
      create(:group_group_link)

      expect(shared_externally?).to be false
    end

    it 'returns true when the group project is shared outside of the namespace hierarchy' do
      create(:project_group_link, project: project, group: external_group)

      expect(shared_externally?).to be true
    end

    it 'returns false when the group project is only shared internally within the namespace hierarchy' do
      create(:project_group_link, project: project, group: subgroup_2)

      expect(shared_externally?).to be false
    end
  end

  it_behaves_like 'can move repository storage' do
    let_it_be(:container) { create(:group, :wiki_repo) }

    let(:repository) { container.wiki.repository }
  end

  describe '#unique_project_download_limit_enabled?' do
    let_it_be(:group) { create(:group) }

    let(:licensed_feature_available) { true }

    before do
      stub_licensed_features(unique_project_download_limit: licensed_feature_available)
    end

    subject { group.unique_project_download_limit_enabled? }

    it { is_expected.to eq true }

    context 'when licensed feature is not available' do
      let(:licensed_feature_available) { false }

      it { is_expected.to eq false }
    end

    context 'when sub-group' do
      let(:subgroup) { create(:group, parent: group) }

      subject { subgroup.unique_project_download_limit_enabled? }

      it { is_expected.to eq false }
    end
  end

  describe '#parent_epic_ids_in_ancestor_groups' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:root_epic) { create(:epic, group: root_group) }
    let_it_be(:unrelated_epic) { create(:epic, group: root_group) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:subepic1) { create(:epic, parent: root_epic, group: subgroup) }
    let_it_be(:subepic2) { create(:epic, parent: epic, group: subgroup) }
    let_it_be(:subepic3) { create(:epic, parent: subepic1, group: subgroup) }

    it 'returns parent ids of epics of the given group that belongs to ancestor groups' do
      stub_const('Group::EPIC_BATCH_SIZE', 1)

      expect(subgroup.parent_epic_ids_in_ancestor_groups).to match_array([epic.id, root_epic.id])
    end
  end

  describe '#has_dependencies?' do
    subject { group.has_dependencies? }

    it 'returns false when group does not have dependencies' do
      is_expected.to eq(false)
    end

    it 'returns true when group does have dependencies' do
      project = create(:project, group: group)
      create(:sbom_occurrence, project: project)

      is_expected.to eq(true)
    end

    it 'returns false if dependencies only exist on archived projects' do
      project = create(:project, :archived, group: group)
      create(:sbom_occurrence, project: project)

      is_expected.to eq(false)
    end
  end

  describe '#sbom_occurrences' do
    subject { group.sbom_occurrences }

    it { is_expected.to be_empty }

    context 'with projects in group' do
      let!(:project) { create(:project, group: group) }
      let!(:archived_project) { create(:project, :archived, group: group) }

      it { is_expected.to be_empty }

      context 'with occurrences' do
        let!(:sbom_occurrence) { create(:sbom_occurrence, project: project) }
        let!(:archived_occurrence) { create(:sbom_occurrence, project: archived_project) }

        it 'returns occurrences from unarchived projects' do
          occurrence = subject.first

          expect(occurrence).to eq(sbom_occurrence)
        end
      end
    end
  end

  describe '#reached_project_access_token_limit?' do
    let(:group) { create(:group) }
    let(:project) { build(:project, namespace: group) }
    let(:bot_user) { create(:user, :project_bot) }

    before_all do
      create(:plan_limits, :ultimate_trial_plan, project_access_token_limit: 1)
    end

    context 'when not in a saas environment' do
      it 'returns false when group project has a token' do
        project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(group.reached_project_access_token_limit?).to eq(false)
      end
    end

    context 'when in a saas environment', :saas do
      before do
        create(:gitlab_subscription, :ultimate_trial, namespace: group)
      end

      it 'returns false when the limit has not been reached' do
        expect(group.reached_project_access_token_limit?).to eq(false)
      end

      it 'returns true when the limit has been reached' do
        project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(group.reached_project_access_token_limit?).to eq(true)
      end

      it 'returns true for a subgroup when a root group project has a token' do
        subgroup = create(:group, parent: group)
        project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(subgroup.reached_project_access_token_limit?).to eq(true)
      end

      it 'returns true for the root group when a subgroup project has a token' do
        subgroup = create(:group, parent: group)
        sub_project = build(:project, namespace: subgroup)
        sub_project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(group.reached_project_access_token_limit?).to eq(true)
      end

      it 'returns true for a subgroup when another subgroup project has a token' do
        subgroup_a = create(:group, parent: group)
        subgroup_b = create(:group, parent: group)
        sub_project = build(:project, namespace: subgroup_a)
        sub_project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(subgroup_b.reached_project_access_token_limit?).to eq(true)
      end

      it 'does not count group tokens' do
        group.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user)

        expect(group.reached_project_access_token_limit?).to eq(false)
      end

      it 'does not count personal tokens' do
        user = create(:user)
        group.add_maintainer(user)
        create(:personal_access_token, user: user)

        expect(group.reached_project_access_token_limit?).to eq(false)
      end

      it 'does not count expired tokens' do
        project.add_maintainer(bot_user)
        create(:personal_access_token, user: bot_user, expires_at: 1.day.ago)

        expect(group.reached_project_access_token_limit?).to eq(false)
      end
    end
  end

  describe '#service_accounts' do
    let!(:service_account) { create(:service_account, provisioned_by_group: group) }
    let!(:service_account_another_group) { create(:service_account, provisioned_by_group: create(:group)) }
    let!(:provisioned_user) { create(:user, provisioned_by_group: group) }

    it 'returns only the group service accounts' do
      expect(group.service_accounts).to eq([service_account])
    end
  end

  describe '.count_within_namespaces' do
    context 'with a single group in the hierarchy' do
      it 'returns one' do
        expect(group.count_within_namespaces).to be 1
      end
    end

    context 'with another group in the hierarchy' do
      before do
        create(:group, parent: group)
      end

      it 'returns two' do
        expect(group.count_within_namespaces).to be 2
      end
    end
  end

  describe '#resource_parent' do
    it 'returns self' do
      expect(group.resource_parent).to eq(group)
    end
  end

  describe '#jira_issues_integration_available?' do
    subject { group.jira_issues_integration_available? }

    context 'licensed' do
      before do
        stub_licensed_features(jira_issues_integration: true)
      end

      it 'returns true for licensed instance' do
        is_expected.to be true
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(jira_issues_integration: false)
      end

      it 'returns false for unlicensed instance' do
        is_expected.to be false
      end
    end
  end

  describe '#multiple_approval_rules_available?' do
    subject { group.multiple_approval_rules_available? }

    context 'licensed' do
      before do
        stub_licensed_features(multiple_approval_rules: true)
      end

      it 'returns true for licensed instance' do
        is_expected.to be true
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(multiple_approval_rules: false)
      end

      it 'returns false for unlicensed instance' do
        is_expected.to be false
      end
    end
  end

  describe '#block_seat_overages?', :saas do
    where(:subscriptions, :seat_control, :user_cap, :result) do
      true  | :off            | nil | false
      true  | :user_cap       | 1   | false
      true  | :block_overages | nil | true
      false | :off            | nil | false
      false | :user_cap       | 1   | false
      false | :block_overages | nil | false
    end

    with_them do
      before do
        stub_saas_features(gitlab_com_subscriptions: subscriptions)
        group.namespace_settings.update!(seat_control: seat_control, new_user_signups_cap: user_cap)
      end

      it 'returns the expected result' do
        expect(group.block_seat_overages?).to eq(result)
      end
    end
  end

  describe 'seat_overage?' do
    let_it_be_with_refind(:group) { create(:group) }

    context 'without a gitlab subscription' do
      it 'returns false' do
        expect(group.seat_overage?).to eq(false)
      end
    end

    context 'with a gitlab subscription', :saas do
      let_it_be(:subscription) { create(:gitlab_subscription, :ultimate, namespace: group, seats: 1) }

      context 'with a reactive cache hit' do
        before do
          synchronous_reactive_cache(group)
        end

        it 'returns false when there are available seats' do
          expect(group.seat_overage?).to eq(false)
        end

        it 'returns false when all seats are taken, but there is no overage' do
          group.add_developer(create(:user))

          expect(group.seat_overage?).to eq(false)
        end

        it 'returns true when the number of users exceeds the number of seats' do
          group.add_developer(create(:user))
          group.add_developer(create(:user))

          expect(group.seat_overage?).to eq(true)
        end

        it 'does not count non-billable members as consuming a seat' do
          group.add_developer(create(:user))
          group.add_guest(create(:user))

          expect(group.seat_overage?).to eq(false)
        end
      end

      context 'with a reactive cache miss' do
        before do
          stub_reactive_cache(group, nil)
        end

        it 'returns false' do
          group.add_developer(create(:user))
          group.add_developer(create(:user))

          expect(group.seat_overage?).to eq(false)
        end
      end
    end
  end

  describe '#licensed_ai_features_available?' do
    subject { group.licensed_ai_features_available? }

    where(:ai_features, :ai_chat, :licensed_ai_features_available) do
      true | true | true
      true | false | true
      false | true | true
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(ai_features: ai_features, ai_chat: ai_chat)
      end

      it { is_expected.to be(licensed_ai_features_available) }
    end
  end

  describe '#licensed_duo_core_features_available?' do
    subject { group.licensed_duo_core_features_available? }

    where(:code_suggestions, :ai_chat, :result) do
      true  | true  | true
      true  | false | true
      false | true  | true
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(code_suggestions: code_suggestions, ai_chat: ai_chat)
      end

      it { is_expected.to be(result) }
    end
  end

  describe '#code_suggestions_purchased?', :saas do
    let(:group) { create(:group) }

    context 'when code suggestions purchase exists' do
      let!(:active_addon) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active, namespace: group)
      end

      it 'returns true' do
        expect(group.code_suggestions_purchased?).to eq(true)
      end
    end

    context 'when code suggestions purchase does not exists' do
      let!(:expired_addon) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace: group)
      end

      it 'returns false' do
        expect(group.code_suggestions_purchased?).to eq(false)
      end
    end
  end

  describe '#enable_auto_assign_gitlab_duo_pro_seats?' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }

    context 'when the feature flag is globally enabled' do
      it 'returns false for non-root namespace' do
        expect(subgroup.enable_auto_assign_gitlab_duo_pro_seats?).to be_falsey
      end

      it 'returns true when namespace_settings.enable_auto_assign_gitlab_duo_pro_seats is enabled' do
        root_group.namespace_settings.update!(enable_auto_assign_gitlab_duo_pro_seats: true)

        expect(root_group.enable_auto_assign_gitlab_duo_pro_seats?).to be_truthy
      end

      it 'returns false when namespace_settings.enable_auto_assign_gitlab_duo_pro_seats is disabled' do
        root_group.namespace_settings.update!(enable_auto_assign_gitlab_duo_pro_seats: false)

        expect(root_group.enable_auto_assign_gitlab_duo_pro_seats?).to be_falsey
      end
    end

    context 'when the feature flag is disabled globally' do
      before do
        stub_feature_flags(auto_assign_gitlab_duo_pro_seats: false)
      end

      it 'returns false' do
        expect(root_group.enable_auto_assign_gitlab_duo_pro_seats?).to be_falsey
      end
    end

    context 'when the feature flag is enabled for a specific group' do
      before do
        stub_feature_flags(auto_assign_gitlab_duo_pro_seats: root_group)
      end

      it 'returns true when namespace_settings.enable_auto_assign_gitlab_duo_pro_seats is enabled' do
        root_group.namespace_settings.update!(enable_auto_assign_gitlab_duo_pro_seats: true)

        expect(root_group.enable_auto_assign_gitlab_duo_pro_seats?).to be_truthy
      end

      it 'returns false for non-root namespace' do
        expect(subgroup.enable_auto_assign_gitlab_duo_pro_seats?).to be_falsey
      end

      it 'returns false when namespace_settings.enable_auto_assign_gitlab_duo_pro_seats is disabled' do
        root_group.namespace_settings.update!(enable_auto_assign_gitlab_duo_pro_seats: false)

        expect(root_group.enable_auto_assign_gitlab_duo_pro_seats?).to be_falsey
      end
    end
  end

  describe '#share_with_group_lock' do
    let_it_be_with_refind(:group) { create(:group) }
    let(:settings) { group.namespace_settings }

    context 'when the namespace settings seat_control is set to user_cap', :saas do
      before do
        group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 1)
      end

      it 'cannot be set to false' do
        group.update!(share_with_group_lock: false)

        expect(group.share_with_group_lock).to eq(true)
      end
    end

    it 'becomes enabled when block seat overages becomes enabled', :saas do
      expect(group.share_with_group_lock).to eq(false)

      settings.update!(seat_control: :block_overages)

      expect(group.reload.share_with_group_lock).to eq(true)
    end

    context 'when block seat overages is already enabled for the group', :saas do
      before do
        settings.update!(seat_control: :block_overages)
      end

      it 'cannot be disabled' do
        group.update!(share_with_group_lock: false)

        expect(group.reload.share_with_group_lock).to eq(true)
      end
    end
  end

  describe '#work_item_epics_enabled?' do
    let_it_be(:group) { build(:group) }

    subject { group.work_item_epics_enabled? }

    context 'when license is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it { is_expected.to be true }
    end

    context 'when license is unavailable' do
      before do
        stub_licensed_features(epics: false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#supports_group_work_items?' do
    subject(:supports_group_work_items?) { group.supports_group_work_items? }

    context 'when epics are licensed' do
      before do
        stub_licensed_features(epics: true)
      end

      it { is_expected.to eq(true) }
    end

    context 'when epics are not licensed' do
      before do
        stub_licensed_features(epics: false)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#work_item_epics_ssot_enabled?' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: root_group) }

    subject { sub_group.work_item_epics_ssot_enabled? }

    context 'when enabled for root ancestor' do
      before do
        stub_feature_flags(work_item_epics_ssot: root_group)
      end

      it { is_expected.to eq(true) }
    end

    context 'when enabled for sub group' do
      before do
        stub_feature_flags(work_item_epics_ssot: sub_group)
      end

      it { is_expected.to eq(false) }
    end

    context 'when disabled for root ancestor' do
      before do
        stub_feature_flags(work_item_epics_ssot: false)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#work_item_status_feature_available?' do
    subject { group.work_item_status_feature_available? }

    context 'when work_item_status licensed feature is enabled' do
      before do
        stub_licensed_features(work_item_status: true)
      end

      it { is_expected.to be true }
    end

    context 'when work_item_status licensed feature is disabled' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it { is_expected.to be false }
    end

    context 'when work_item_status_feature_flag is disabled' do
      before do
        stub_feature_flags(work_item_status_feature_flag: false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#can_manage_extensions_marketplace_for_enterprise_users?' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: root_group) }

    subject(:can_manage_extensions_marketplace_for_enterprise_users?) { group.can_manage_extensions_marketplace_for_enterprise_users? }

    where(:group, :licensed_feature_available, :settings_enabled, :expected) do
      ref(:root_group)  | true  | true  | true
      ref(:child_group) | true  | true  | false
      ref(:root_group)  | false | true  | false
      ref(:root_group)  | true  | false | false
    end

    with_them do
      before do
        allow(::WebIde::ExtensionMarketplace).to receive(:feature_enabled_from_application_settings?).and_return(settings_enabled)
        stub_licensed_features(disable_extensions_marketplace_for_enterprise_users: licensed_feature_available)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe "#active_compliance_frameworks?" do
    let_it_be(:framework) { create :compliance_framework }
    let_it_be(:group) { framework.namespace }

    context 'without default framework' do
      context 'without assigned projects' do
        it 'returns false' do
          expect(group.active_compliance_frameworks?).to be false
        end
      end

      context 'with assigned projects' do
        let_it_be(:project) { create :project, namespace: group }

        it 'returns true' do
          ComplianceManagement::ComplianceFramework::ProjectSettings.find_or_create_by_project(project, framework)

          expect(group.reset.active_compliance_frameworks?).to be true
        end
      end
    end

    context 'with default framework' do
      before do
        group.namespace_settings.update!(default_compliance_framework_id: framework.id)
      end

      context 'without assigned projects' do
        it 'returns false' do
          expect(group.active_compliance_frameworks?).to be false
        end
      end

      context 'with assigned projects' do
        let_it_be(:project) { create :project, namespace: group }

        it 'returns true' do
          ComplianceManagement::ComplianceFramework::ProjectSettings.find_or_create_by_project(project, framework)

          expect(group.reset.active_compliance_frameworks?).to be true
        end
      end
    end
  end

  describe '#enterprise_users_extensions_marketplace_enabled?' do
    let_it_be(:group) { create(:group) }

    subject(:enterprise_users_extensions_marketplace_enabled?) { group.enterprise_users_extensions_marketplace_enabled? }

    where(:value, :licensed_feature_available, :expected) do
      true  | true  | true
      false | true  | false
      false | false | true
    end

    with_them do
      before do
        group.update!(enterprise_users_extensions_marketplace_enabled: value)
        allow(::WebIde::ExtensionMarketplace).to receive(:feature_enabled_from_application_settings?).and_return(true)
        stub_licensed_features(disable_extensions_marketplace_for_enterprise_users: licensed_feature_available)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#extended_grat_expiry_webhooks_execute?' do
    let(:group) { create(:group) }

    context 'when extended_grat_expiry_webhooks_execute = true' do
      before do
        group.extended_grat_expiry_webhooks_execute = true
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        it 'delegates the field to namespace settings and return true' do
          expect(group.namespace_settings).to receive(:extended_grat_expiry_webhooks_execute?).and_call_original

          expect(group.extended_grat_expiry_webhooks_execute?).to be_truthy
        end
      end

      it 'returns false if licensed feature is not available' do
        expect(group.extended_grat_expiry_webhooks_execute?).to be_truthy
      end
    end

    context 'when extended_grat_expiry_webhooks_execute=false' do
      before do
        group.extended_grat_expiry_webhooks_execute = false
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        it 'delegates the field to namespace settings and returns false' do
          expect(group.namespace_settings).to receive(:extended_grat_expiry_webhooks_execute?).and_call_original

          expect(group.extended_grat_expiry_webhooks_execute?).to be_falsey
        end
      end
    end
  end

  describe '#scim_identities' do
    let(:group) { create(:group) }
    let(:group_scim_identity) { create(:group_scim_identity, group: group) }

    it 'returns group_scim_identities' do
      expect(group.scim_identities).to match_array([group_scim_identity])
    end
  end

  describe '#scim_oauth_access_token' do
    let(:group) { create(:group) }
    let!(:group_scim_token) { create(:group_scim_auth_access_token, group: group) }

    it 'returns group_scim_identities' do
      expect(group.scim_auth_access_token).to eql(group_scim_token)
    end
  end

  describe '#destroy' do
    it_behaves_like 'create audits for user add-on assignments' do
      let(:entity) { group }
    end
  end

  describe '#ai_review_merge_request_allowed?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:current_user) { create(:user, developer_of: group) }

    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    subject(:ai_review_merge_request_allowed?) { group.ai_review_merge_request_allowed?(current_user) }

    before do
      # Set up the "happy path" - all conditions return true by default
      stub_licensed_features(review_merge_request: true)
      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
      allow(authorizer).to receive(:allowed?).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :access_ai_review_mr, group).and_return(true)
    end

    # When all conditions are true, the method should return true
    it { is_expected.to be(true) }

    context 'when feature is not authorized' do
      before do
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when user lacks permission' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :access_ai_review_mr, group).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#project_epics_enabled?' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: root_group) }

    subject { sub_group.project_epics_enabled? }

    context 'when FF enabled for root ancestor' do
      before do
        stub_feature_flags(project_work_item_epics: root_group)
      end

      it { is_expected.to eq(true) }
    end

    context 'when FF enabled for sub group' do
      before do
        stub_feature_flags(project_work_item_epics: sub_group)
      end

      it { is_expected.to eq(true) }
    end

    context 'when FF is disabled for root ancestor' do
      before do
        stub_feature_flags(project_work_item_epics: false)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#virtual_registry_policy_subject' do
    subject { group.virtual_registry_policy_subject }

    it { is_expected.to be_a(::VirtualRegistries::Packages::Policies::Group).and have_attributes(group:) }
  end

  describe '#lifecycles' do
    context 'with system-defined lifecycles' do
      let_it_be(:system_defined_lifecycles) { ::WorkItems::Statuses::SystemDefined::Lifecycle.all }

      it 'returns system-defined lifecycles' do
        expect(group.lifecycles).to eq(system_defined_lifecycles)
      end
    end

    context 'with custom lifecycles' do
      let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

      it 'returns custom lifecycles' do
        expect(group.lifecycles).to contain_exactly(custom_lifecycle)
      end
    end
  end
end
