# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UserAuthorizable, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  let(:expected_allowed) { true }
  let(:expected_namespace_ids) { [] }
  let(:expected_enablement_type) { nil }
  let(:expected_authorized_by_duo_core) { false }
  let(:expected_response) do
    described_class::Response.new(
      allowed?: expected_allowed,
      namespace_ids: expected_namespace_ids,
      enablement_type: expected_enablement_type,
      authorized_by_duo_core: expected_authorized_by_duo_core)
  end

  describe '#allowed_to_use' do
    let(:ai_feature) { :my_feature }
    let(:duo_core_features_enabled) { true }
    let(:service_name) { ai_feature }
    let(:maturity) { :ga }
    let(:free_access) { true }
    let(:service) { CloudConnector::BaseAvailableServiceData.new(service_name, nil, %w[duo_pro]) }

    let_it_be(:gitlab_add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:expired_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_add_on)
    end

    let_it_be_with_reload(:active_gitlab_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_add_on)
    end

    before do
      stub_const("Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", { ai_feature => { maturity: maturity } })

      allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(service_name).and_return(service)
      allow(service).to receive(:free_access?).and_return(free_access)
    end

    subject { user.allowed_to_use(ai_feature) }

    shared_examples_for 'checking assigned seats' do
      context 'when the service data is missing' do
        let(:service) { CloudConnector::MissingServiceData.new }
        let(:expected_allowed) { false }

        it { is_expected.to eq expected_response }
      end

      context 'when the AI feature is missing' do
        let(:expected_allowed) { false }

        before do
          stub_const("Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", {})
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has an active assigned seat' do
        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { allowed_by_namespace_ids }
        let(:expected_enablement_type) { 'duo_pro' }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: active_gitlab_purchase
          )
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has an active assigned duo enterprise seat' do
        let_it_be_with_reload(:enterprise_gitlab_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be_with_reload(:enterprise_gitlab_purchase) do
          create(:gitlab_subscription_add_on_purchase, add_on: enterprise_gitlab_add_on)
        end

        let(:expected_allowed) { true }
        let(:expected_namespace_ids) { Array(enterprise_gitlab_purchase.namespace_id) }
        let(:expected_enablement_type) { 'duo_enterprise' }

        let(:service) { CloudConnector::BaseAvailableServiceData.new(service_name, nil, %w[duo_enterprise]) }

        before do
          allow(service).to receive_messages(free_access?: free_access)

          enterprise_gitlab_purchase.update!(namespace: namespace)
          namespace&.add_owner(user)

          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: enterprise_gitlab_purchase
          )
        end

        it { is_expected.to eq expected_response }
      end

      context 'when the user has a Duo Core subscription' do
        let_it_be_with_reload(:active_gitlab_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_core)
        end

        let(:expected_allowed) { true }
        let(:expected_enablement_type) { 'duo_core' }
        let(:expected_namespace_ids) { allowed_by_namespace_ids }
        let(:expected_authorized_by_duo_core) { true }
        let(:free_access) { false }
        let(:service) { CloudConnector::BaseAvailableServiceData.new(service_name, nil, %w[duo_pro duo_core]) }

        it { is_expected.to eq expected_response }

        context 'when duo_core_saas feature flag is disabled' do
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { !feature_flag_blocks_access }
          let(:expected_enablement_type) { 'duo_core' unless feature_flag_blocks_access }
          let(:expected_authorized_by_duo_core) { !feature_flag_blocks_access }

          before do
            stub_feature_flags(duo_core_saas: false)
          end

          it { is_expected.to eq expected_response }
        end

        context 'when access is denied' do
          let(:allowed_by_namespace_ids) { [] }
          let(:expected_allowed) { false }
          let(:expected_enablement_type) { nil }
          let(:expected_authorized_by_duo_core) { false }

          context 'when user is not active' do
            let(:user) { create(:user, :blocked) }

            it { is_expected.to eq expected_response }
          end

          context 'when user is is a bot' do
            let(:user) { create(:user, :bot) }

            it { is_expected.to eq expected_response }
          end

          context 'when duo_core_features_enabled is false' do
            let(:duo_core_features_enabled) { false }

            it { is_expected.to eq expected_response }
          end

          context 'when the Duo service is not available through Duo Core' do
            let(:service) { CloudConnector::BaseAvailableServiceData.new(service_name, nil, %w[duo_pro]) }

            it { is_expected.to eq expected_response }
          end
        end
      end

      context "when the user doesn't have an active assigned seat and free access is not available" do
        let(:free_access) { false }
        let(:expected_allowed) { false }

        it { is_expected.to eq expected_response }

        context 'when the user has an expired seat' do
          before do
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: expired_gitlab_purchase
            )
          end

          it { is_expected.to eq expected_response }
        end
      end
    end

    context 'when on Gitlab.com instance', :saas do
      let(:namespace) { active_gitlab_purchase.namespace }
      let(:allowed_by_namespace_ids) { [namespace.id] }

      before do
        namespace.add_owner(user)
      end

      include_examples 'checking assigned seats' do
        let(:feature_flag_blocks_access) { true }

        before do
          namespace.namespace_settings.update!(
            duo_core_features_enabled: duo_core_features_enabled
          )
        end
      end

      context "when the user doesn't have a seat but the service has free access" do
        context "when the user doesn't belong to any namespaces with eligible plans" do
          let(:expected_allowed) { false }

          it { is_expected.to eq expected_response }
        end

        context "when the user belongs to groups with eligible plans" do
          let_it_be_with_reload(:group) do
            create(:group_with_plan, plan: :ultimate_plan)
          end

          let_it_be_with_reload(:group_without_experiment_features_enabled) do
            create(:group_with_plan, plan: :ultimate_plan)
          end

          before_all do
            group.add_guest(user)
            group_without_experiment_features_enabled.add_guest(user)
          end

          # TODO: Change to use context 'with ai features enabled for group'
          # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/497781
          before do
            allow(Gitlab).to receive(:org_or_com?).and_return(true)
            stub_ee_application_setting(should_check_namespace_plan: true)
            stub_licensed_features(
              ai_features: true,
              glab_ask_git_command: true,
              generate_description: true
            )
            group.namespace_settings.reload.update!(experiment_features_enabled: true)
          end

          shared_examples 'checking available groups' do
            let(:expected_namespace_ids) { [group.id, group_without_experiment_features_enabled.id] }
            let(:expected_enablement_type) { 'tier' }

            it { is_expected.to eq expected_response }

            context 'when the feature is not GA' do
              let(:expected_namespace_ids) { [group.id] }
              let(:maturity) { :beta }

              it { is_expected.to eq expected_response }

              context "when none of the user groups have experiment features enabled" do
                let(:expected_allowed) { false }
                let(:expected_namespace_ids) { [] }
                let(:expected_enablement_type) { nil }

                before do
                  group.namespace_settings.update!(experiment_features_enabled: false)
                end

                it { is_expected.to eq expected_response }
              end
            end
          end

          it_behaves_like 'checking available groups'

          describe 'returning namespace ids that allow using a feature' do
            let(:expected_enablement_type) { 'tier' }
            let(:expected_namespace_ids) { [group.id, group_without_experiment_features_enabled.id] }

            it { is_expected.to eq expected_response }

            context 'when the feature is not GA' do
              let(:maturity) { :beta }
              let(:expected_namespace_ids) { [group.id] }

              it { is_expected.to eq expected_response }
            end
          end

          context 'when specifying a service name' do
            let(:service_name) { :my_service }

            subject { user.allowed_to_use(ai_feature, service_name: service_name) }

            it_behaves_like 'checking available groups'
          end
        end
      end
    end

    context 'when on Self managed instance' do
      using RSpec::Parameterized::TableSyntax

      let(:namespace) { nil }

      let_it_be_with_reload(:active_gitlab_purchase) do
        create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: gitlab_add_on)
      end

      include_examples 'checking assigned seats' do
        let(:allowed_by_namespace_ids) { [] }
        let(:feature_flag_blocks_access) { false }

        before do
          # AddOnPurchase.for_user scope (used for Duo Core)
          # returns nil in SM instances if add-on
          # purchases are associated with namespaces
          active_gitlab_purchase.update!(namespace: nil)
          ::Ai::Setting.instance.update!(duo_core_features_enabled: duo_core_features_enabled)
        end
      end

      context "when the user doesn't have a seat but the service has free access" do
        shared_examples 'when checking licensed features' do
          let(:licensed_feature) { :ai_features }

          where(:licensed_feature_available, :free_access, :expected_allowed) do
            true  | true  | true
            true  | false | false
            false | true  | false
          end

          with_them do
            before do
              stub_licensed_features(licensed_feature => licensed_feature_available)
            end

            it { is_expected.to eq expected_response }
          end
        end

        it_behaves_like 'when checking licensed features'

        context 'when specifying a service name' do
          let(:service_name) { :my_service }

          before do
            stub_licensed_features(ai_features: true)
          end

          subject { user.allowed_to_use(ai_feature, service_name: service_name) }

          it { is_expected.to eq expected_response }
        end

        context 'when specifying a licensed feature name' do
          it_behaves_like 'when checking licensed features' do
            let(:licensed_feature) { :generate_commit_message }

            subject(:allowed_to_use) { user.allowed_to_use(ai_feature, licensed_feature: licensed_feature) }
          end
        end
      end
    end
  end

  context 'when amazon q integration is connected' do
    subject { user.allowed_to_use(ai_feature) }

    let_it_be(:access_data) do
      create(:cloud_connector_access, data: {
        available_services: [
          { name: "amazon_q_integration", serviceStartTime: 2.days.ago, bundledWith: %w[duo_amazon_q] },
          { name: "duo_chat", serviceStartTime: 2.days.ago, bundledWith: %w[duo_enterprise] },
          { name: "review_merge_request", serviceStartTime: 2.days.ago, bundledWith: %w[duo_enterprise] }
        ]
      })
    end

    let_it_be(:gitlab_subscription_add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_amazon_q)
    end

    let_it_be(:gitlab_subscription_user_add_on_assignment) do
      duo_pro_purchase = create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_enterprise)
      create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: duo_pro_purchase)
    end

    using RSpec::Parameterized::TableSyntax

    where(:amazon_q_connected, :ai_feature, :expected_enablement_type) do
      false | :duo_chat | 'duo_enterprise'
      true  | :duo_chat | 'duo_amazon_q'
      true  | :code_suggestions | 'duo_amazon_q'
      true  | :troubleshoot_job | 'duo_amazon_q'
      true  | :explain_vulnerability | 'duo_amazon_q'
      true  | :resolve_vulnerability | 'duo_amazon_q'
      true  | :summarize_comments | 'duo_amazon_q'
      true  | :review_merge_request | 'duo_enterprise'
    end

    with_them do
      before do
        Ai::Setting.instance.update!(amazon_q_ready: amazon_q_connected)
        stub_licensed_features(amazon_q: true)
      end

      it 'checks whether the feature is available in Amazon Q' do
        is_expected.to eq(expected_response)
      end
    end
  end

  describe '#allowed_to_use?' do
    let(:ai_feature) { :my_feature }

    subject { user.allowed_to_use?(ai_feature, service_name: :duo_chat, licensed_feature: :ai_features) }

    it 'checks allowed_to_use object' do
      expect(user).to receive(:allowed_to_use).with(
        ai_feature,
        service_name: :duo_chat,
        licensed_feature: :ai_features
      ).and_return(expected_response)

      is_expected.to eq(true)
    end
  end

  describe '#allowed_by_namespace_ids' do
    let(:ai_feature) { :my_feature }

    subject { user.allowed_by_namespace_ids(ai_feature) }

    context "when allowed_to_use doesn't return any namespace ids" do
      before do
        allow(user).to receive(:allowed_to_use).with(ai_feature)
          .and_return(described_class::Response.new(allowed?: true, namespace_ids: []))
      end

      it { is_expected.to eq([]) }
    end

    context 'when allowed_to_use returns namespace ids' do
      let(:namespace_ids) { [1, 2] }

      before do
        allow(user).to receive(:allowed_to_use).with(ai_feature)
          .and_return(described_class::Response.new(allowed?: true, namespace_ids: namespace_ids))
      end

      it { is_expected.to eq(namespace_ids) }
    end
  end

  describe '#any_group_with_ai_available?', :saas, :use_clean_rails_redis_caching do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_reload(:bronze_group) { create(:group_with_plan, plan: :bronze_plan) }
    let_it_be_with_reload(:free_group) { create(:group_with_plan, plan: :free_plan) }
    let_it_be_with_reload(:group_without_plan) { create(:group) }
    let_it_be_with_reload(:trial_group) do
      create(
        :group_with_plan,
        plan: :ultimate_plan,
        trial: true,
        trial_starts_on: Date.current,
        trial_ends_on: 1.day.from_now
      )
    end

    let_it_be_with_reload(:ultimate_sub_group) { create(:group, parent: ultimate_group) }
    let_it_be_with_reload(:bronze_sub_group) { create(:group, parent: bronze_group) }

    subject(:group_with_ai_enabled) { user.any_group_with_ai_available? }

    where(:group, :result) do
      ref(:bronze_group)       | false
      ref(:free_group)         | false
      ref(:group_without_plan) | false
      ref(:ultimate_group)     | true
      ref(:trial_group)        | true
    end

    with_them do
      context 'when member of the root group' do
        before do
          group.add_guest(user)
        end

        context 'when ai features are enabled' do
          include_context 'with ai features enabled for group'

          it { is_expected.to eq(result) }

          it 'caches the result' do
            group_with_ai_enabled

            expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to eq(result)
          end
        end

        context 'when ai features are not enabled' do
          it { is_expected.to eq(false) }
        end
      end
    end

    context 'when member of a sub-group only' do
      include_context 'with ai features enabled for group'

      context 'with eligible group' do
        let(:group) { ultimate_group }

        before_all do
          ultimate_sub_group.add_guest(user)
        end

        it { is_expected.to eq(true) }
      end

      context 'with not eligible group' do
        let(:group) { bronze_group }

        before_all do
          bronze_sub_group.add_guest(user)
        end

        it { is_expected.to eq(false) }
      end
    end

    context 'when member of a project only' do
      include_context 'with ai features enabled for group'

      context 'with eligible group' do
        let(:group) { ultimate_group }
        let_it_be(:project) { create(:project, group: ultimate_group) }

        before_all do
          project.add_guest(user)
        end

        it { is_expected.to eq(true) }
      end

      context 'with not eligible group' do
        let(:group) { bronze_group }
        let_it_be(:project) { create(:project, group: bronze_group) }

        before_all do
          project.add_guest(user)
        end

        it { is_expected.to eq(false) }
      end
    end
  end

  shared_examples 'returns IDs of namespaces with duo add-on' do
    let_it_be(:gitlab_duo_add_on) { create(:gitlab_subscription_add_on, add_on_type) }

    let_it_be(:expired_gitlab_duo_purchase) do
      create(:gitlab_subscription_add_on_purchase, expires_on: 1.day.ago, add_on: gitlab_duo_add_on)
    end

    let_it_be_with_reload(:active_gitlab_duo_purchase) do
      create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_add_on)
    end

    context 'when the user has an active assigned duo seat' do
      it 'returns the namespace ID' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_purchase
        )

        expect(duo_namespace_ids).to eq([active_gitlab_duo_purchase.namespace_id])
      end
    end

    context 'when the user belongs to multiple namespaces with an active assigned duo seat' do
      let!(:active_gitlab_duo_pro_purchase_2) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_add_on)
      end

      it 'returns the namespace IDs' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_purchase
        )

        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_2
        )

        expect(duo_namespace_ids)
          .to contain_exactly(active_gitlab_duo_purchase.namespace_id,
            active_gitlab_duo_pro_purchase_2.namespace_id)
      end
    end

    context 'when the user has an expired assigned duo seat' do
      it 'returns empty' do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_duo_purchase
        )

        expect(duo_namespace_ids).to be_empty
      end
    end

    context 'when the user has no add on seat assignments' do
      it 'returns empty' do
        expect(duo_namespace_ids).to be_empty
      end
    end
  end

  describe '#duo_pro_add_on_available_namespace_ids', :saas do
    it_behaves_like 'returns IDs of namespaces with duo add-on' do
      subject(:duo_namespace_ids) { user.duo_pro_add_on_available_namespace_ids }

      let_it_be(:add_on_type) { :duo_pro }
    end
  end

  describe '#duo_available_namespace_ids' do
    context 'when user has duo pro add-on' do
      it_behaves_like 'returns IDs of namespaces with duo add-on' do
        subject(:duo_namespace_ids) { user.duo_available_namespace_ids }

        let_it_be(:add_on_type) { :duo_pro }
      end
    end

    context 'when user has duo enterprise add-on' do
      it_behaves_like 'returns IDs of namespaces with duo add-on' do
        subject(:duo_namespace_ids) { user.duo_available_namespace_ids }

        let_it_be(:add_on_type) { :duo_enterprise }
      end
    end
  end

  describe '#eligible_for_self_managed_gitlab_duo_pro?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:active_user) { create(:user) }
    let_it_be(:bot) { create(:user, :bot) }
    let_it_be(:ghost) { create(:user, :ghost) }
    let_it_be(:blocked_user) { create(:user, :blocked) }
    let_it_be(:banned_user) { create(:user, :banned) }
    let_it_be(:pending_approval_user) { create(:user, :blocked_pending_approval) }
    let_it_be(:group) { create(:group) }
    let_it_be(:guest_user) { create(:group_member, :guest, source: group).user }

    context 'when on gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns false by default' do
        expect(active_user.eligible_for_self_managed_gitlab_duo_pro?).to be_falsey
      end
    end

    context 'when on self managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      # True for human users, excluding bots, blocked, banned, and pending_approval users.
      where(:user, :result) do
        ref(:bot)                     | false
        ref(:ghost)                   | false
        ref(:blocked_user)            | false
        ref(:banned_user)             | false
        ref(:pending_approval_user)   | false
        ref(:active_user)             | true
        ref(:guest_user)              | true
      end

      with_them do
        subject { user.eligible_for_self_managed_gitlab_duo_pro? }

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#billable_gitlab_duo_pro_root_group_ids', :use_clean_rails_redis_caching do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:root_group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: root_group) }
    let_it_be(:group_project) { create(:project, group: root_group) }
    let_it_be(:sub_group_project) { create(:project, group: sub_group) }

    subject { user.billable_gitlab_duo_pro_root_group_ids }

    context 'when on gitlab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      shared_examples 'excludes root_group_ids for banned user' do
        context 'when the user is banned' do
          let(:result) { [] }

          before do
            create(:namespace_ban, namespace: root_group, user: user)
          end

          it { is_expected.to eq(result) }
        end
      end

      where(:access_level, :include_group) do
        :guest      | false
        :reporter   | true
        :developer  | true
        :maintainer | true
        :owner      | true
      end

      with_them do
        let(:result) { include_group ? [root_group.id] : [] }

        context 'when the user is a member of the top level group' do
          before do
            root_group.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it 'caches the result' do
            user.billable_gitlab_duo_pro_root_group_ids

            expect(
              Rails.cache.fetch(['users', user.id, described_class::BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY])
            ).to eq(result)
          end
        end

        context 'when the user is a member of a sub group of the top level group' do
          before do
            sub_group.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root_group_ids for banned user'
        end

        context 'when the user is a member of a project within the top level group' do
          before do
            group_project.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root_group_ids for banned user'
        end

        context 'when the user is a member of a project within a sub group of the top level group' do
          before do
            sub_group_project.add_member(user, access_level)
          end

          it { is_expected.to eq(result) }

          it_behaves_like 'excludes root_group_ids for banned user'
        end

        context 'when the user is a member of an invited group' do
          let_it_be(:invited_group) { create(:group) }

          before do
            invited_group.add_member(user, access_level)
          end

          where(:shared_group_access_level, :include_group_via_link) do
            :guest      | false
            :reporter   | true
            :developer  | true
            :maintainer | true
            :owner      | true
          end

          context 'when the group is invited to a project' do
            with_them do
              let(:result) { include_group && include_group_via_link ? [root_group.id] : [] }

              before do
                create(:project_group_link, project: project, group: invited_group)
              end

              it { is_expected.to eq(result) }
            end
          end

          context 'when the group is invited to a group' do
            with_them do
              let(:result) { include_group && include_group_via_link ? [root_group.id] : [] }

              before do
                create(:group_group_link, shared_group: group, shared_with_group: invited_group)
              end

              it { is_expected.to eq(result) }
            end
          end
        end
      end
    end

    context 'when on self managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it { is_expected.to eq(nil) }
    end
  end

  describe '#duo_pro_cache_key_formatted' do
    it 'formats the cache key correctly' do
      formatted_cache_key = user.duo_pro_cache_key_formatted
      expected_cache_key = "user-#{user.id}-code-suggestions-add-on-cache"

      expect(formatted_cache_key).to eq(expected_cache_key)
    end
  end

  describe '.clear_group_with_ai_available_cache', :use_clean_rails_redis_caching do
    let_it_be(:other_user) { create(:user) }
    let_it_be(:yet_another_user) { create(:user) }
    let_it_be(:billable_groups_user) { create(:user) }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      user.any_group_with_ai_available?
      other_user.any_group_with_ai_available?

      billable_groups_user.billable_gitlab_duo_pro_root_group_ids
    end

    it 'clears cache from users with the given ids', :aggregate_failures do
      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to eq(false)
      expect(Rails.cache.fetch(['users', other_user.id, 'group_with_ai_enabled'])).to eq(false)
      expect(Rails.cache.fetch(['users', billable_groups_user.id,
        described_class::BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY])).to eq([])

      User.clear_group_with_ai_available_cache([user.id, yet_another_user.id, billable_groups_user.id])

      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be_nil
      expect(Rails.cache.fetch(['users', other_user.id, 'group_with_ai_enabled'])).to eq(false)
      expect(Rails.cache.fetch(['users', billable_groups_user.id,
        described_class::BILLABLE_DUO_PRO_ROOT_GROUP_IDS_CACHE_KEY])).to be_nil
    end

    it 'clears cache when given a single id', :aggregate_failures do
      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to eq(false)

      User.clear_group_with_ai_available_cache(user.id)

      expect(Rails.cache.fetch(['users', user.id, 'group_with_ai_enabled'])).to be_nil
    end
  end

  describe '.duo_pro_cache_key_formatted' do
    it 'formats the cache key correctly' do
      formatted_cache_key = User.duo_pro_cache_key_formatted(123)
      expected_cache_key = 'user-123-code-suggestions-add-on-cache'

      expect(formatted_cache_key).to eq(expected_cache_key)
    end
  end
end
