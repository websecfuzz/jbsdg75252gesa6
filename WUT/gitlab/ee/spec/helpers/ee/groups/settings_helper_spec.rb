# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Groups::SettingsHelper, feature_category: :groups_and_projects do
  let(:namespace_settings) do
    build(:namespace_settings, unique_project_download_limit: 1,
      unique_project_download_limit_interval_in_seconds: 2,
      unique_project_download_limit_allowlist: %w[username1 username2],
      unique_project_download_limit_alertlist: [3, 4],
      auto_ban_user_on_excessive_projects_download: true)
  end

  let(:ai_settings) do
    build(:namespace_ai_settings, duo_workflow_mcp_enabled: true)
  end

  let(:group) { build(:group, namespace_settings: namespace_settings, ai_settings: ai_settings, id: 7) }
  let(:current_user) { build(:user) }

  before do
    helper.instance_variable_set(:@group, group)
    allow(helper).to receive(:current_user).and_return(current_user)
    allow(helper).to receive(:instance_variable_get).with(:@current_user).and_return(current_user)
    allow(::GitlabSubscriptions::AddOnPurchase)
      .to receive_message_chain(:for_self_managed, :for_duo_pro_or_duo_enterprise, :active, :first)
  end

  describe '.unique_project_download_limit_settings_data', feature_category: :insider_threat do
    subject { helper.unique_project_download_limit_settings_data }

    it 'returns the expected data' do
      is_expected.to eq({ group_full_path: group.full_path,
                          max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#group_ai_general_settings_helper_data' do
    subject(:group_ai_general_settings_helper_data) { helper.group_ai_general_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_general_settings_helper_data).to include(
        on_general_settings_page: 'true',
        redirect_path: edit_group_path(group),
        base_data: 'data'
      )
    end
  end

  describe '#group_ai_configuration_settings_helper_data' do
    subject(:group_ai_configuration_settings_helper_data) { helper.group_ai_configuration_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_configuration_settings_helper_data).to include(
        on_general_settings_page: 'false',
        redirect_path: group_settings_gitlab_duo_path(group),
        base_data: 'data'
      )
    end
  end

  describe 'group_ai_settings_helper_data' do
    subject { helper.group_ai_settings_helper_data }

    let(:add_on_purchase) { nil }
    let(:root_ancestor) { group }

    before do
      allow(helper).to receive(:show_early_access_program_banner?).and_return(true)
      allow(current_user).to receive(:can?).with(:admin_duo_workflow, group).and_return(true)
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          cascading_settings_data: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_availability: group.namespace_settings.duo_availability.to_s,
          duo_core_features_enabled: group.namespace_settings.duo_core_features_enabled.to_s,
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?.to_s,
          experiment_features_enabled: group.namespace_settings.experiment_features_enabled.to_s,
          prompt_cache_enabled: group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          show_early_access_banner: "true",
          early_access_path: group_early_access_opt_in_path(group),
          update_id: group.id,
          duo_workflow_available: "true",
          duo_workflow_mcp_enabled: "true",
          is_saas: 'true'
        }
      )
    end

    context 'with GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'return is_saas as true' do
        is_expected.to include(is_saas: 'false')
      end
    end
  end

  describe 'group_amazon_q_settings_view_model_data' do
    subject(:group_amazon_q_settings_view_model_data) { helper.group_amazon_q_settings_view_model_data }

    before do
      group.amazon_q_integration = build(:amazon_q_integration, instance: false, auto_review_enabled: true)
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          group_id: group.id.to_s,
          init_availability: group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: true,
          cascading_settings_data: { locked_by_application_setting: false, locked_by_ancestor: false },
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?
        }
      )
    end
  end

  describe 'group_amazon_q_settings_view_model_json' do
    subject(:group_amazon_q_settings_view_model_json) { helper.group_amazon_q_settings_view_model_json }

    it 'returns the expected data' do
      is_expected.to eq(
        {
          groupId: "7",
          initAvailability: "default_on",
          initAutoReviewEnabled: false,
          areDuoSettingsLocked: false,
          cascadingSettingsData: { lockedByApplicationSetting: false, lockedByAncestor: false }
        }.to_json
      )
    end
  end

  describe 'show_group_ai_settings_general?' do
    let(:duo_settings_available?) { true }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
    let(:root_ancestor) { create(:group) }
    let(:group) { create(:group, parent: root_ancestor) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    before do
      allow(GitlabSubscriptions::Duo)
        .to receive(:duo_settings_available?)
        .with(root_ancestor)
        .and_return(duo_settings_available?)
    end

    it { expect(helper).to be_show_group_ai_settings_general }

    context 'when group has no trial or add-on' do
      let(:duo_settings_available?) { false }

      it { expect(helper).not_to be_show_group_ai_settings_general }
    end
  end

  describe 'show_group_ai_settings_page?' do
    using RSpec::Parameterized::TableSyntax
    subject { helper.show_group_ai_settings_page? }

    where(:licensed_ai_features_available, :show_gitlab_duo_settings_app, :expected_result) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        allow(group).to receive(:licensed_ai_features_available?).and_return(licensed_ai_features_available)
        allow(helper).to receive(:show_gitlab_duo_settings_app?).with(group).and_return(show_gitlab_duo_settings_app)
      end

      it 'returns the expected result' do
        expect(helper.show_group_ai_settings_page?).to eq(expected_result)
      end
    end
  end

  describe 'show_early_access_program_banner?' do
    using RSpec::Parameterized::TableSyntax
    subject { helper.show_early_access_program_banner? }

    where(:feature_enabled, :participant, :experiment_features_enabled, :expected_result) do
      true  | false | true  | true
      true  | false | false | false
      true  | true  | true  | false
      true  | true  | false | false
      false | false | true  | false
      false | false | false | false
      false | true  | true  | false
      false | true  | false | false
    end

    with_them do
      before do
        stub_feature_flags(early_access_program_toggle: feature_enabled)
        current_user.user_preference.update!(early_access_program_participant: participant)
        allow(group).to receive(:experiment_features_enabled).and_return(experiment_features_enabled)
      end

      it 'returns the expected result' do
        expect(helper.show_early_access_program_banner?).to eq(expected_result)
      end
    end
  end
end
