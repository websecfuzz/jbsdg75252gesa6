# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VsCode::Settings::VsCodeSetting, feature_category: :web_ide do
  let!(:user) { create(:user) }
  let!(:setting) { create(:vscode_setting, user: user, setting_type: 'settings', settings_context_hash: nil) }

  describe 'validates the presence of required attributes' do
    it { is_expected.to validate_presence_of(:setting_type) }
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_presence_of(:version) }
  end

  describe 'validates the uniqueness of attributes' do
    context 'when testing setting_type uniqueness' do
      subject do
        build(:vscode_setting,
          setting_type: 'keybindings',
          user: user,
          settings_context_hash: nil
        )
      end

      it { is_expected.to validate_uniqueness_of(:setting_type).scoped_to([:user_id, :settings_context_hash]) }
    end

    context 'when testing settings_context_hash uniqueness' do
      subject do
        build(:vscode_setting,
          setting_type: 'extensions',
          user: user,
          settings_context_hash: 'some_value'
        )
      end

      it { is_expected.to validate_uniqueness_of(:setting_type).scoped_to([:user_id, :settings_context_hash]) }
    end
  end

  describe 'relationship validation' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'settings type validation' do
    it { is_expected.to validate_inclusion_of(:setting_type).in_array(VsCode::Settings::SETTINGS_TYPES) }
  end

  describe 'settings context hash validation' do
    it { is_expected.to validate_length_of(:settings_context_hash).is_at_most(255) }

    context 'when setting type is not extensions' do
      subject { build(:vscode_setting, setting_type: 'settings', settings_context_hash: nil) }

      it { is_expected.to allow_value(nil).for(:settings_context_hash) }
      it { is_expected.not_to allow_value('some_value').for(:settings_context_hash) }
    end

    context 'when setting type is extensions' do
      subject do
        build(:vscode_setting, setting_type: VsCode::Settings::EXTENSIONS, settings_context_hash: 'some_hashed_value')
      end

      it { is_expected.not_to allow_value(nil).for(:settings_context_hash) }
      it { is_expected.to allow_value('some_value').for(:settings_context_hash) }
    end
  end

  describe '.by_setting_types' do
    context 'when setting type is not extensions' do
      subject { described_class.by_setting_types(['settings']) }

      it { is_expected.to contain_exactly(setting) }
    end

    context 'when setting type is extensions' do
      let_it_be(:extension) do
        create(:vscode_setting, setting_type: VsCode::Settings::EXTENSIONS, settings_context_hash: 'a')
      end

      let_it_be(:extension_b) do
        create(:vscode_setting, setting_type: VsCode::Settings::EXTENSIONS, settings_context_hash: 'b')
      end

      subject { described_class.by_setting_types([VsCode::Settings::EXTENSIONS], 'a') }

      it { is_expected.to contain_exactly(extension) }
    end
  end

  describe '.by_user' do
    subject { described_class.by_user(user) }

    it { is_expected.to contain_exactly(setting) }
  end
end
