# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectSetting, feature_category: :groups_and_projects do
  it { is_expected.to belong_to(:push_rule) }
  it { is_expected.to validate_length_of(:product_analytics_instrumentation_key).is_at_most(255).allow_blank }

  it { is_expected.to allow_value('https://test.com').for(:product_analytics_configurator_connection_string) }
  it { is_expected.to allow_value('https://test.com').for(:product_analytics_data_collector_host) }
  it { is_expected.to allow_value('https://test.com').for(:cube_api_base_url) }

  it { is_expected.to allow_value('').for(:product_analytics_configurator_connection_string) }
  it { is_expected.to allow_value('').for(:product_analytics_data_collector_host) }
  it { is_expected.to allow_value('').for(:cube_api_base_url) }
  it { is_expected.to allow_value('').for(:cube_api_key) }

  it { is_expected.not_to allow_value('notavalidurl').for(:product_analytics_configurator_connection_string) }
  it { is_expected.not_to allow_value('notavalidurl').for(:product_analytics_data_collector_host) }
  it { is_expected.not_to allow_value('notavalidurl').for(:cube_api_base_url) }

  it { is_expected.to validate_length_of(:product_analytics_configurator_connection_string).is_at_most(512) }
  it { is_expected.to validate_length_of(:product_analytics_data_collector_host).is_at_most(255) }
  it { is_expected.to validate_length_of(:cube_api_base_url).is_at_most(512) }
  it { is_expected.to validate_length_of(:cube_api_key).is_at_most(255) }

  describe 'duo_context_exclusion_settings validation' do
    it { is_expected.to allow_value({}).for(:duo_context_exclusion_settings) }
    it { is_expected.to allow_value({ exclusion_rules: [] }).for(:duo_context_exclusion_settings) }
    it { is_expected.to allow_value({ exclusion_rules: ['test.log', '.tmp'] }).for(:duo_context_exclusion_settings) }

    it { is_expected.not_to allow_value(nil).for(:duo_context_exclusion_settings) }
    it { is_expected.not_to allow_value('invalid_string').for(:duo_context_exclusion_settings) }
    it { is_expected.not_to allow_value([]).for(:duo_context_exclusion_settings) }
    it { is_expected.not_to allow_value({ exclusion_rules: 'not_an_array' }).for(:duo_context_exclusion_settings) }
    it { is_expected.not_to allow_value({ exclusion_rules: [123, 456] }).for(:duo_context_exclusion_settings) }
    it { is_expected.not_to allow_value({ invalid_property: ['.log'] }).for(:duo_context_exclusion_settings) }

    it 'now allow extra properties' do
      is_expected.not_to allow_value({ exclusion_rules: ['.log'],
     extra_property: 'no' }).for(:duo_context_exclusion_settings)
    end
  end

  describe '.has_vulnerabilities' do
    let_it_be(:setting_1) { create(:project_setting, :has_vulnerabilities) }
    let_it_be(:setting_2) { create(:project_setting) }

    subject { described_class.has_vulnerabilities }

    it { is_expected.to contain_exactly(setting_1) }
  end

  describe '.has_confluence?' do
    let_it_be(:setting) { create(:project_setting, has_confluence: true) }

    subject { setting }

    it { is_expected.to have_confluence }

    it 'is false when the confluence integration is blocked by settings' do
      allow(Integrations::Confluence).to receive(:blocked_by_settings?).and_return(true)

      is_expected.not_to have_confluence
    end
  end

  describe 'all_or_none_product_analytics_attributes_set' do
    let_it_be(:setting) { create(:project_setting) }

    subject { setting }

    context 'when setting all values' do
      before do
        setting.update( # rubocop:disable Rails/SaveBang -- We need to test validity in the subject
          product_analytics_configurator_connection_string: 'https://test.com',
          product_analytics_data_collector_host: 'https://test.net',
          cube_api_base_url: 'https://test.org',
          cube_api_key: 'thisisnotasecret'
        )
      end

      it { is_expected.to be_valid }
    end

    context 'when setting no values' do
      before do
        setting.update( # rubocop:disable Rails/SaveBang -- We need to test validity in the subject
          product_analytics_configurator_connection_string: nil,
          product_analytics_data_collector_host: nil,
          cube_api_base_url: nil,
          cube_api_key: nil
        )
      end

      it { is_expected.to be_valid }
    end

    context 'when setting some values' do
      before do
        setting.update( # rubocop:disable Rails/SaveBang -- We need to test validity in the subject
          product_analytics_configurator_connection_string: nil,
          product_analytics_data_collector_host: 'https://test.net',
          cube_api_base_url: 'https://test.org',
          cube_api_key: 'thisisnotasecret'
        )
      end

      it { is_expected.not_to be_valid }
    end
  end

  describe '.duo_features_set' do
    let_it_be(:setting_1) { create(:project_setting, duo_features_enabled: true) }
    let_it_be(:setting_2) { create(:project_setting, duo_features_enabled: false) }

    subject { described_class.duo_features_set(true) }

    it { is_expected.to contain_exactly(setting_1) }
  end

  describe 'validations' do
    context 'when enabling only_mirror_protected_branches and mirror_branch_regex' do
      it 'is invalid' do
        project = build(:project, only_mirror_protected_branches: true)
        setting = build(:project_setting, project: project, mirror_branch_regex: 'text')

        expect(setting).not_to be_valid
      end
    end

    context 'when disable only_mirror_protected_branches and enable mirror_branch_regex' do
      let_it_be(:project) { build(:project, only_mirror_protected_branches: false) }

      it 'is valid' do
        setting = build(:project_setting, project: project, mirror_branch_regex: 'test')

        expect(setting).to be_valid
      end

      it 'is invalid with invalid regex' do
        setting = build(:project_setting, project: project, mirror_branch_regex: '\\')

        expect(setting).not_to be_valid
      end
    end
  end

  describe '#duo_features_enabled' do
    it_behaves_like 'a cascading project setting boolean attribute', settings_attribute_name: :duo_features_enabled
  end

  describe '#spp_repository_pipeline_access' do
    it_behaves_like 'a cascading project setting boolean attribute',
      settings_attribute_name: :spp_repository_pipeline_access
  end

  describe '#model_prompt_cache_enabled' do
    it_behaves_like 'a cascading project setting boolean attribute',
      settings_attribute_name: :model_prompt_cache_enabled
  end
end
