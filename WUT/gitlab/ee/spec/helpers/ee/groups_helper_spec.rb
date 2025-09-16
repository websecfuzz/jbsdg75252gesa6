# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsHelper, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let(:owner) { create(:user, group_view: :security_dashboard) }
  let(:current_user) { owner }
  let(:group) { create(:group, :private, name: 'Test Group') }

  before do
    allow(helper).to receive(:current_user) { current_user }
    helper.instance_variable_set(:@group, group)

    group.add_owner(owner)
  end

  describe '#render_setting_to_allow_project_access_token_creation?' do
    context 'with self-managed' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:group) { create(:group, parent: parent) }

      before do
        parent.add_owner(owner)
        group.add_owner(owner)
      end

      it 'returns true if group is root' do
        expect(helper.render_setting_to_allow_project_access_token_creation?(parent)).to eq(true)
      end

      it 'returns false if group is subgroup' do
        expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
      end
    end

    context 'on .com', :saas do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'with a free plan' do
        let_it_be(:group) { create(:group) }

        it 'returns false' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
        end
      end

      context 'with a paid plan' do
        let_it_be(:parent) { create(:group_with_plan, plan: :bronze_plan) }
        let_it_be(:group) { create(:group, parent: parent) }

        before do
          parent.add_owner(owner)
        end

        it 'returns true if group is root' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(parent)).to eq(true)
        end

        it 'returns false if group is subgroup' do
          expect(helper.render_setting_to_allow_project_access_token_creation?(group)).to eq(false)
        end
      end
    end
  end

  describe '#show_discover_group_security?' do
    using RSpec::Parameterized::TableSyntax

    where(
      gitlab_com?: [true, false],
      user?: [true, false],
      security_dashboard_feature_available?: [true, false],
      can_admin_group?: [true, false]
    )

    with_them do
      it 'returns the expected value' do
        allow(helper).to receive(:current_user) { user? ? owner : nil }
        allow(::Gitlab).to receive(:com?) { gitlab_com? }
        allow(group).to receive(:licensed_feature_available?) { security_dashboard_feature_available? }
        allow(helper).to receive(:can?) { can_admin_group? }

        expected_value = user? && gitlab_com? && !security_dashboard_feature_available? && can_admin_group?

        expect(helper.show_discover_group_security?(group)).to eq(expected_value)
      end
    end
  end

  describe '#show_group_activity_analytics?' do
    before do
      stub_licensed_features(group_activity_analytics: feature_available)

      allow(helper).to receive(:current_user) { current_user }
      allow(helper).to receive(:can?) { |*args| Ability.allowed?(*args) }
    end

    context 'when feature is not available for group' do
      let(:feature_available) { false }

      it 'returns false' do
        expect(helper.show_group_activity_analytics?).to be false
      end
    end

    context 'when current user does not have access to the group' do
      let(:feature_available) { true }
      let(:current_user) { create(:user) }

      it 'returns false' do
        expect(helper.show_group_activity_analytics?).to be false
      end
    end

    context 'when feature is available and user has access to it' do
      let(:feature_available) { true }

      it 'returns true' do
        expect(helper.show_group_activity_analytics?).to be true
      end
    end
  end

  describe '#show_user_cap_alert?' do
    before do
      allow(group).to receive(:user_cap_available?).and_return(user_cap_applied)
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    describe 'when user cap is available' do
      let(:user_cap_applied) { true }

      describe 'when user cap value is set' do
        before do
          group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 10)
        end

        describe 'when user is an owner of the root namespace' do
          it { expect(helper.show_user_cap_alert?).to be true }
        end

        describe 'when user is not an owner of the root namespace' do
          let(:current_user) { create(:user) }

          it { expect(helper.show_user_cap_alert?).to be false }
        end
      end

      describe 'when user cap is off' do
        before do
          group.namespace_settings.update!(seat_control: :off)
        end

        describe 'when user is an owner of the root namespace' do
          it { expect(helper.show_user_cap_alert?).to be false }
        end
      end

      context 'when namespace settings is nil' do
        let(:group) { build(:group) }

        it { expect(helper.show_user_cap_alert?).to be false }
      end
    end

    describe 'when user cap is not available' do
      let(:user_cap_applied) { false }

      it { expect(helper.show_user_cap_alert?).to be false }
    end
  end

  describe '#pending_members_link' do
    it { expect(helper.pending_members_link).to eq link_to('', pending_members_group_usage_quotas_path(group)) }

    describe 'for a sub-group' do
      let(:sub_group) { create(:group, :private, parent: group) }

      before do
        helper.instance_variable_set(:@group, sub_group)
      end

      it 'returns a link to the root group' do
        expect(helper.pending_members_link).to eq link_to('', pending_members_group_usage_quotas_path(group))
      end
    end
  end

  describe '#show_product_purchase_success_alert?' do
    describe 'when purchased_product is present' do
      before do
        allow(controller).to receive(:params) { { purchased_product: product } }
      end

      where(:product, :result) do
        'product' | true
        ''        | false
        nil       | false
      end

      with_them do
        it { expect(helper.show_product_purchase_success_alert?).to be result }
      end
    end

    describe 'when purchased_product is not present' do
      it { expect(helper.show_product_purchase_success_alert?).to be false }
    end
  end

  describe '#group_seats_usage_quota_app_data' do
    subject(:group_seats_usage_quota_app_data) { helper.group_seats_usage_quota_app_data(group) }

    let(:enforcement_free_user_cap) { false }
    let(:data) do
      {
        namespace_id: group.id,
        namespace_name: group.name,
        is_public_namespace: group.public?.to_s,
        full_path: group.full_path,
        seat_usage_export_path: group_seat_usage_path(group, format: :csv),
        add_seats_href: subscription_portal_add_extra_seats_url(group.id),
        subscription_history_href: subscription_history_group_usage_quotas_path(group),
        max_free_namespace_seats: 10,
        explore_plans_path: group_billings_path(group),
        enforcement_free_user_cap_enabled: 'false'
      }
    end

    before do
      stub_ee_application_setting(dashboard_limit: 10)

      expect_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group) do |instance|
        expect(instance).to receive(:enforce_cap?).and_return(enforcement_free_user_cap)
      end
    end

    context 'when free user cap is enforced' do
      let(:enforcement_free_user_cap) { true }
      let(:expected_data) { data.merge({ enforcement_free_user_cap_enabled: 'true' }) }

      it { is_expected.to eql(expected_data) }
    end

    context 'when is private namespace' do
      let(:expected_data) { data.merge({ is_public_namespace: 'false' }) }

      it { is_expected.to eql(expected_data) }
    end

    context 'when is public namespace' do
      let_it_be(:group) { create(:group, :public) }

      let(:expected_data) { data.merge({ is_public_namespace: 'true' }) }

      it { is_expected.to eql(expected_data) }
    end
  end

  describe '#duo_home_app_data' do
    let(:namespace_settings) { group.namespace_settings }

    subject(:duo_home_app_data) { helper.duo_home_app_data(group) }

    before do
      allow(helper).to receive(:code_suggestions_usage_app_data).and_return({ code_suggestions: 'data' })
    end

    it 'returns a hash with expected values and merges the result of code_suggestions_usage_app_data' do
      namespace_settings.update!(
        duo_availability: 'default_on',
        experiment_features_enabled: true,
        duo_core_features_enabled: true
      )

      expect(helper.duo_home_app_data(group)).to eq({
        duo_seat_utilization_path: '/groups/test_group/-/settings/gitlab_duo/seat_utilization',
        duo_availability: 'default_on',
        experiment_features_enabled: 'true',
        prompt_cache_enabled: 'true',
        duo_configuration_path: '/groups/test_group/-/settings/gitlab_duo/configuration',
        code_suggestions: 'data',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        are_duo_core_features_enabled: 'true',
        model_switching_enabled: 'true',
        model_switching_path: '/groups/test_group/-/settings/gitlab_duo/model_selection'
      })
    end

    context 'with disabled duo_core_features_enabled' do
      before do
        namespace_settings.update!(duo_core_features_enabled: false)
      end

      it 'sets Duo Core flag to false' do
        expect(helper.duo_home_app_data(group)).to include(are_duo_core_features_enabled: 'false')
      end
    end

    context 'with feature flag ai_model_switching set to false' do
      before do
        stub_feature_flags(ai_model_switching: false)
      end

      it 'sets model_switching_enabled to false' do
        expect(helper.duo_home_app_data(group)).to include(model_switching_enabled: 'false')
      end
    end
  end

  describe '#code_suggestions_usage_app_data' do
    subject(:code_suggestions_usage_app_data) { helper.code_suggestions_usage_app_data(group) }

    let(:include_trial_link) { true }
    let(:trial_link) do
      { duo_pro_trial_href: ::Gitlab::Routing.url_helpers.new_trials_duo_pro_path(namespace_id: group.id) }
    end

    let(:data) do
      {
        full_path: group.full_path,
        group_id: group.id,
        add_duo_pro_href: ::Gitlab::Routing.url_helpers.subscription_portal_add_saas_duo_pro_seats_url(group.id),
        hand_raise_lead: helper.code_suggestions_usage_app_hand_raise_lead_data,
        is_free_namespace: group.has_free_or_no_subscription?.to_s,
        buy_subscription_path: group_billings_path(group),
        duo_page_path: group_settings_gitlab_duo_path(group)
      }.merge(trial_link)
    end

    before do
      allow(GitlabSubscriptions::DuoPro)
        .to receive(:no_add_on_purchase_for_namespace?).with(group).and_return(include_trial_link)
      allow(GitlabSubscriptions::DuoPro)
        .to receive(:namespace_eligible?).with(group).and_return(include_trial_link)
    end

    context 'when duo pro bulk assignment is available' do
      it { is_expected.to eql(data.merge(duo_pro_bulk_user_assignment_available: 'true')) }
    end
  end

  describe '#active_subscription_data' do
    context 'when there is a current subscription', :saas do
      let(:subscription) { create(:gitlab_subscription, namespace: group) }

      before do
        group.gitlab_subscription = subscription
      end

      it 'returns the subscription start date and end date' do
        expect(helper.active_subscription_data(group)).to eq({
          subscription_start_date: subscription.start_date,
          subscription_end_date: subscription.end_date
        })
      end
    end

    context 'when there is no current subscription' do
      it 'returns empty' do
        expect(helper.active_subscription_data(group)).to eq({})
      end
    end
  end

  describe '#active_duo_add_on_data' do
    context 'when an active duo add on is a trial' do
      let(:trial_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: group) }

      it 'returns the trial start date and end date' do
        trial_add_on

        expect(helper.active_duo_add_on_data(group)).to eq({
          duo_add_on_is_trial: 'true',
          duo_add_on_start_date: trial_add_on.started_at,
          duo_add_on_end_date: trial_add_on.expires_on
        })
      end
    end

    context 'when an active duo add on is not a trial' do
      let(:add_on) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: group) }

      it 'returns the trial start date and end date' do
        add_on

        expect(helper.active_duo_add_on_data(group)).to eq({
          duo_add_on_is_trial: 'false',
          duo_add_on_start_date: add_on.started_at,
          duo_add_on_end_date: add_on.expires_on - ::EE::GroupsHelper.const_get(:SUBSCRIPTION_GRACE_PERIOD, false)
        })
      end
    end

    context 'when an active duo add on does not exist' do
      it 'returns empty' do
        expect(helper.active_duo_add_on_data(group)).to eq({})
      end
    end
  end

  describe '#product_analytics_usage_quota_app_data' do
    subject(:product_analytics_usage_quota_app_data) { helper.product_analytics_usage_quota_app_data(group) }

    before do
      allow(helper).to receive(:image_path).and_return('illustrations/empty-state/empty-dashboard-md.svg')
    end

    let(:data) do
      {
        namespace_path: group.full_path,
        empty_state_illustration_path: "illustrations/empty-state/empty-dashboard-md.svg"
      }
    end

    context 'when product analytics is disabled' do
      before do
        stub_application_setting(product_analytics_enabled?: false)
      end

      it { is_expected.to eql(data.merge({ product_analytics_enabled: "false" })) }
    end

    context 'when product analytics is enabled' do
      before do
        stub_application_setting(product_analytics_enabled?: true)
      end

      it { is_expected.to eql(data.merge({ product_analytics_enabled: "true" })) }
    end
  end

  describe '#show_usage_quotas_tab?' do
    context 'when tab does not exist' do
      it { expect(helper.show_usage_quotas_tab?(group, :nonexistent_tab)).to be false }
    end

    context 'when on seats tab' do
      where(license_feature_available: [true, false])

      with_them do
        before do
          stub_licensed_features(seat_usage_quotas: license_feature_available)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :seats)).to eq(license_feature_available) }
      end
    end

    context 'when on code suggestions tab' do
      where(:show_gitlab_duo_settings_app?, :result) do
        true | true
        false | false
      end

      with_them do
        before do
          allow(helper).to receive(:show_gitlab_duo_settings_app?).and_return(show_gitlab_duo_settings_app?)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :code_suggestions)).to eq(result) }
      end

      context 'on self managed' do
        before do
          stub_licensed_features(code_suggestions: true)
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :code_suggestions)).to be_falsy }
      end
    end

    context 'when on pipelines tab' do
      where(:license_feature_available, :can_admin_ci_minutes, :result) do
        true | true | true
        true | false | false
        false | false | false
        false | true | false
      end

      with_them do
        before do
          stub_licensed_features(pipelines_usage_quotas: license_feature_available)
          allow(Ability).to receive(:allowed?).with(current_user, :admin_ci_minutes, group)
            .and_return(can_admin_ci_minutes)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :pipelines)).to eq(result) }
      end
    end

    context 'when on transfer tab' do
      where(:license_feature_available, :ff_enabled, :result) do
        true | true | true
        true | false | false
        false | false | false
        false | true | false
      end

      with_them do
        before do
          stub_licensed_features(transfer_usage_quotas: license_feature_available)
          stub_feature_flags(data_transfer_monitoring: ff_enabled)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :transfer)).to eq(result) }
      end
    end

    context 'when on product analytics tab' do
      where(license_feature_available: [true, false])

      with_them do
        before do
          stub_licensed_features(product_analytics_usage_quotas: license_feature_available)
        end

        it { expect(helper.show_usage_quotas_tab?(group, :product_analytics)).to eq(license_feature_available) }
      end
    end
  end

  describe '#can_invite_group_member?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when licensed feature is not available' do
      before do
        stub_licensed_features(disable_invite_members: false)
      end

      context  'when application setting to disable_invite_members is enabled' do
        before do
          stub_application_setting(disable_invite_members: true)
        end

        it 'returns true for the group owner' do
          group.add_owner(user)

          expect(helper.can_invite_group_member?(group)).to be(true)
        end

        it 'returns false for non group owner' do
          group.add_developer(user)

          expect(helper.can_invite_group_member?(group)).to be(false)
        end

        it 'returns true for admin user', :enable_admin_mode do
          user.update_attribute(:admin, true)

          expect(helper.can_invite_group_member?(group)).to be(true)
        end
      end
    end

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(disable_invite_members: true)
      end

      context  'when application setting to disable_invite_members is enabled' do
        before do
          stub_application_setting(disable_invite_members: true)
        end

        it 'returns false for the group owner' do
          group.add_owner(user)

          expect(helper.can_invite_group_member?(group)).to be(false)
        end

        context 'when user is admin' do
          before do
            user.update_attribute(:admin, true)
          end

          it 'returns false for instance admin without admin mode' do
            expect(helper.can_invite_group_member?(group)).to be(false)
          end

          it 'returns true for instance admin with admin mode', :enable_admin_mode do
            expect(helper.can_invite_group_member?(group)).to be(true)
          end
        end
      end
    end
  end

  describe '#saml_sso_settings_generate_helper_text' do
    let(:text) { 'some text' }
    let(:result) { "<span class=\"js-helper-text gl-clearfix\">#{text}</span>" }

    specify { expect(helper.saml_sso_settings_generate_helper_text(display_none: false, text: text)).to eq result }
    specify { expect(helper.saml_sso_settings_generate_helper_text(display_none: true, text: text)).to include('gl-hidden') }
  end

  describe '#group_transfer_app_data' do
    it 'returns expected hash' do
      expect(helper.group_transfer_app_data(group)).to eq({
        full_path: group.full_path
      })
    end
  end

  describe '#subgroup_creation_data' do
    subject { helper.subgroup_creation_data(group) }

    it 'returns expected hash' do
      expect(subject).to include({
        identity_verification_required: 'false',
        identity_verification_path: identity_verification_path
      })
    end

    context 'when self-managed' do
      it { is_expected.to include(is_saas: 'false') }
    end

    context 'when on .com', :saas do
      it { is_expected.to include(is_saas: 'true') }
    end

    context 'when the group creation limit is not exceeded' do
      it { is_expected.to include(identity_verification_required: 'false') }
    end

    context 'when the group creation limit is exceeded' do
      before do
        allow(current_user).to receive(:requires_identity_verification_to_create_group?).and_return(true)
      end

      it { is_expected.to include(identity_verification_required: 'true') }
    end
  end

  describe '#access_level_roles_user_can_assign' do
    subject { helper.access_level_roles_user_can_assign(group, roles) }

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:user) { create(:user) }

    context 'when user is provided' do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      context 'when a user is a group member' do
        before do
          group.add_developer(user)
        end

        context 'when the passed roles include the minimal access role and the minimal access role is available' do
          let(:roles) { group.access_level_roles }

          before do
            stub_licensed_features(minimal_access_role: true)
          end

          it 'includes the minimal access role' do
            expect(subject).to include(EE::Gitlab::Access::MINIMAL_ACCESS_HASH)
          end
        end

        context 'when the passed roles do not include the minimal access role' do
          let(:roles) { GroupMember.access_level_roles }

          it 'does not include the minimal access role' do
            expect(subject).not_to include(EE::Gitlab::Access::MINIMAL_ACCESS_HASH)
          end
        end
      end
    end
  end

  describe '#pages_deployments_app_data' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:project2) { create(:project, namespace: group) }

    before_all do
      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
      project2.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
      project.project_setting.update!(pages_unique_domain_enabled: false)
      project2.project_setting.update!(pages_unique_domain_enabled: true, pages_unique_domain: 'example.com')
      create(:pages_deployment, project: project, path_prefix: '/foo')
      create(:pages_deployment, project: project2, path_prefix: '/foo')
    end

    it 'returns expected hash' do
      expect(helper.pages_deployments_app_data(group)).to match(
        {
          full_path: group.full_path,
          deployments_count: 1,
          deployments_limit: 100,
          deployments_by_project: [
            {
              name: project.name,
              count: 1
            }
          ].to_json
        }
      )
    end
  end
end
