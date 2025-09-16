# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectSecuritySetting, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    subject { create(:project).security_setting }

    it { is_expected.to belong_to(:project) }
  end

  describe '#set_continuous_vulnerability_scans' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, continuous_vulnerability_scans_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_continuous_vulnerability_scans!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.continuous_vulnerability_scans_enabled).to eq(value_after)
      end
    end
  end

  describe '#set_container_scanning_for_registry' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_container_scanning_for_registry!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.container_scanning_for_registry_enabled).to eq(value_after)
      end
    end

    context 'when changing container_scanning_for_registry_enabled value' do
      let(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: false) }

      it 'schedules analyzer status update worker when value changes' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with([setting.project_id], 'container_scanning')

        setting.set_container_scanning_for_registry!(enabled: true)
      end
    end

    context 'when updating container_scanning_for_registry_enabled value to the already existing value' do
      let!(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: false) }

      it 'does not schedule worker when value does not change' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        setting.set_container_scanning_for_registry!(enabled: false)
      end
    end
  end

  describe '#set_secret_push_protection' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, secret_push_protection_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_secret_push_protection!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.secret_push_protection_enabled).to eq(value_after)
      end
    end

    context 'when changing secret_push_protection_enabled value' do
      let!(:setting) { create(:project_security_setting, secret_push_protection_enabled: false) }

      it 'schedules analyzer status update worker when value changes' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with([setting.project_id], 'secret_detection')

        setting.set_secret_push_protection!(enabled: true)
      end
    end

    context 'when updating secret_push_protection_enabled value to the already existing value' do
      let!(:setting) { create(:project_security_setting, secret_push_protection_enabled: false) }

      it 'does not schedule worker when value does not change' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        setting.set_secret_push_protection!(enabled: false)
      end
    end
  end

  describe '#set_validity_checks' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, validity_checks_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_validity_checks!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.validity_checks_enabled).to eq(value_after)
      end
    end
  end

  describe 'after_commit hooks' do
    where(:field, :value_before, :update_value, :worker_scheduled, :type) do
      :container_scanning_for_registry_enabled | false | true  | true  | 'container_scanning'
      :container_scanning_for_registry_enabled | true  | false | true  | 'container_scanning'
      :container_scanning_for_registry_enabled | false | false | false | 'container_scanning'
      :container_scanning_for_registry_enabled | true  | true  | false | 'container_scanning'
      :secret_push_protection_enabled          | false | true  | true  | 'secret_detection'
      :secret_push_protection_enabled          | true  | false | true  | 'secret_detection'
      :secret_push_protection_enabled          | false | false | false | 'secret_detection'
      :secret_push_protection_enabled          | true  | true  | false | 'secret_detection'
      # Different field not covered by the hook:
      :validity_checks_enabled                 | true  | false | false | nil
    end

    with_them do
      let!(:setting) { create(:project_security_setting, field => value_before) }

      it 'schedules worker appropriately when field changes' do
        if worker_scheduled
          expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
            .to receive(:perform_async).with([setting.project_id], type)
        else
          expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
            .not_to receive(:perform_async)
        end

        setting.update!(field => update_value)
      end
    end

    describe 'when creating a new project' do
      it 'schedules SettingChangedUpdateWorker worker for each analyzer status related type' do
        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with(anything, 'container_scanning')

        expect(Security::AnalyzersStatus::SettingChangedUpdateWorker)
          .to receive(:perform_async).with(anything, 'secret_detection')

        create(:project)
      end
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      let_it_be(:project_1) { create(:project) }
      let_it_be(:project_2) { create(:project) }
      let_it_be(:project_3) { create(:project) }

      it 'only returns security settings for selected projects' do
        expect(described_class.for_projects([project_1.id, project_2.id]))
          .to match_array([project_1.security_setting, project_2.security_setting])
      end
    end
  end
end
