# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillLicensesOutsideSpdxCatalogue, feature_category: :security_policy_management do
  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }

  let(:software_licenses) { table(:software_licenses) }
  let(:custom_software_licenses) { table(:custom_software_licenses) }
  let(:software_license_policies) { table(:software_license_policies) }

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let!(:namespace) { namespaces.create!(name: 'namespace', path: 'namespace', organization_id: organization.id) }
  let!(:project) do
    projects.create!(namespace_id: namespace.id, project_namespace_id: namespace.id, organization_id: organization.id)
  end

  subject(:perform_migration) do
    described_class.new(
      start_id: software_license_policies.minimum(:id),
      end_id: software_license_policies.maximum(:id),
      batch_table: :software_license_policies,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 2.minutes,
      connection: ApplicationRecord.connection
    ).perform
  end

  shared_examples 'does not create a new custom software license' do
    it 'does not create a new custom software license' do
      expect { perform_migration }.not_to change { custom_software_licenses.count }
    end
  end

  shared_examples 'creates a new custom software license' do
    it 'creates a new custom software license' do
      expect { perform_migration }.to change { custom_software_licenses.count }.by(1)
    end
  end

  shared_examples_for 'when the software license policy has the custom_software_license_id set' do
    it_behaves_like 'does not create a new custom software license'

    it 'does not change the custom_software_license_id' do
      expect { perform_migration }.not_to change { software_license_policy.reload.custom_software_license_id }
    end
  end

  context 'when the software license policy has the software_license_spdx_identifier set' do
    let(:software_license_spdx_identifier) { 'MIT' }
    let!(:mit_license) do
      software_licenses.create!(name: 'MIT License', spdx_identifier: software_license_spdx_identifier)
    end

    let!(:software_license_policy) do
      software_license_policies.create!(project_id: project.id, software_license_id: mit_license.id,
        software_license_spdx_identifier: software_license_spdx_identifier)
    end

    it 'does not backfill the custom_software_license_id' do
      expect(software_license_policy.custom_software_license_id).to be_nil

      perform_migration

      software_license_policy.reload

      expect(software_license_policy.custom_software_license_id).to be_nil
    end
  end

  context 'when the software license policy has the custom_software_license_id set' do
    let(:custom_license_name) { 'Custom License' }
    let!(:custom_software_license) do
      custom_software_licenses.create!(name: custom_license_name, project_id: project.id)
    end

    let(:custom_software_license_id) { custom_software_license.id }

    let!(:software_license_policy) do
      software_license_policies.create!(project_id: project.id,
        custom_software_license_id: custom_software_license_id)
    end

    it_behaves_like 'when the software license policy has the custom_software_license_id set'
  end

  context 'when the software license policy does not have the software_license_spdx_identifier set' do
    let(:software_license_outside_spdx_name) { 'Software License Outside SPDX' }
    let!(:software_license_outside_spdx) do
      software_licenses.create!(name: 'Software License Outside SPDX', spdx_identifier: nil)
    end

    let!(:software_license_policy) do
      software_license_policies.create!(project_id: project.id,
        software_license_id: software_license_outside_spdx.id, software_license_spdx_identifier: nil,
        custom_software_license_id: custom_software_license_id)
    end

    context 'when the software license policy has the custom_software_license_id set' do
      let!(:custom_software_license) do
        custom_software_licenses.create!(name: software_license_outside_spdx_name, project_id: project.id)
      end

      let!(:custom_software_license_id) { custom_software_license.id }

      it_behaves_like 'when the software license policy has the custom_software_license_id set'
    end

    context 'when the software license policy does not have the custom_software_license_id set' do
      let(:custom_software_license_id) { nil }

      context 'when the custom_software_licenses table does not contain an entry with the same name and project_id' do
        it_behaves_like 'creates a new custom software license'

        it 'backfill the custom_software_license_id' do
          expect(software_license_policy.software_license_id).to eq(software_license_outside_spdx.id)
          expect(software_license_policy.custom_software_license_id).to be_nil

          perform_migration

          software_license_policy.reload
          custom_software_license = custom_software_licenses.last

          expect(software_license_policy.software_license_id).to eq(software_license_outside_spdx.id)
          expect(software_license_policy.custom_software_license_id).to eq(custom_software_license.id)
        end
      end

      context 'when the custom_software_licenses table contains an entry with the same name and project_id' do
        let!(:existing_custom_software_license) do
          custom_software_licenses.create!(name: software_license_outside_spdx_name, project_id: project.id)
        end

        it_behaves_like 'does not create a new custom software license'

        it 'backfill the custom_software_license_id with the existing custom_software_license' do
          expect(software_license_policy.software_license_id).to eq(software_license_outside_spdx.id)
          expect(software_license_policy.custom_software_license_id).to be_nil

          perform_migration

          software_license_policy.reload

          expect(software_license_policy.software_license_id).to eq(software_license_outside_spdx.id)
          expect(software_license_policy.custom_software_license_id).to eq(existing_custom_software_license.id)
        end
      end
    end
  end
end
