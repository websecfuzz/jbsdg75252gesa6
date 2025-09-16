# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSoftwareLicenseSpdxIdentifierForSoftwareLicensePolicies,
  feature_category: :security_policy_management,
  schema: 20241115211552 do
  let(:software_licenses_table) { table(:software_licenses) }
  let(:software_license_policies_table) { table(:software_license_policies) }
  let(:projects_table) { table(:projects) }
  let(:namespace_table) { table(:namespaces) }

  let!(:namespace) { namespace_table.create!(name: 'namespace', path: 'namespace') }
  let!(:project) { projects_table.create!(namespace_id: namespace.id, project_namespace_id: namespace.id) }

  subject(:perform_migration) do
    described_class.new(
      start_id: software_license_policies_table.minimum(:id),
      end_id: software_license_policies_table.maximum(:id),
      batch_table: :software_license_policies,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 2.minutes,
      connection: ApplicationRecord.connection
    ).perform
  end

  context 'when there are software license policies linked to software licenses' do
    let!(:mit_license) { software_licenses_table.create!(name: 'MIT License', spdx_identifier: 'MIT') }
    let!(:software_license_policy) do
      software_license_policies_table.create!(project_id: project.id,
        software_license_id: mit_license.id)
    end

    it 'backfill the spdx_identifier without removing the software_license_id' do
      expect(software_license_policy.software_license_id).to eq(mit_license.id)
      expect(software_license_policies_table.last.software_license_spdx_identifier).to be_nil

      perform_migration

      software_license_policy.reload

      expect(software_license_policy.software_license_id).to eq(mit_license.id)
      expect(software_license_policy.software_license_spdx_identifier).to eq(mit_license.spdx_identifier)
    end

    context 'when the same software license is linked to multiple software license policies' do
      let!(:other_namespace) { namespace_table.create!(name: 'other_namespace', path: 'other_namespace') }
      let!(:other_project) do
        projects_table.create!(namespace_id: namespace.id,
          project_namespace_id: other_namespace.id)
      end

      let!(:other_software_license_policy) do
        software_license_policies_table.create!(project_id: other_project.id,
          software_license_id: mit_license.id)
      end

      it 'backfill the spdx_identifier for all software license policies without removing the software_license_id' do
        expect(software_license_policy.software_license_id).to eq(mit_license.id)
        expect(software_license_policy.software_license_spdx_identifier).to be_nil

        expect(other_software_license_policy.software_license_id).to eq(mit_license.id)
        expect(other_software_license_policy.software_license_spdx_identifier).to be_nil

        perform_migration

        software_license_policy.reload
        other_software_license_policy.reload

        expect(software_license_policy.software_license_id).to eq(mit_license.id)
        expect(software_license_policy.software_license_spdx_identifier).to eq(mit_license.spdx_identifier)

        expect(other_software_license_policy.software_license_id).to eq(mit_license.id)
        expect(other_software_license_policy.software_license_spdx_identifier).to eq(mit_license.spdx_identifier)
      end
    end

    context 'when the software license spdx is nil' do
      let!(:mit_license) { software_licenses_table.create!(name: 'MIT License', spdx_identifier: nil) }

      it 'does not backfill the spdx_identifier' do
        expect(software_license_policies_table.last.software_license_spdx_identifier).to be_nil

        perform_migration

        software_license_policy.reload

        expect(software_license_policy.software_license_spdx_identifier).to be_nil
      end
    end
  end

  context 'when the software license policy is linked to a custom license' do
    let(:custom_software_licenses_table) { table(:custom_software_licenses) }

    let(:custom_license_name) { 'Custom License' }
    let!(:custom_software_license) do
      custom_software_licenses_table.create!(name: custom_license_name, project_id: project.id)
    end

    let!(:software_license_policy) do
      software_license_policies_table.create!(project_id: project.id,
        custom_software_license_id: custom_software_license.id)
    end

    it 'does not backfill the spdx_identifier for all software license policies' do
      expect(software_license_policy.software_license_id).to be_nil
      expect(software_license_policy.software_license_spdx_identifier).to be_nil
      expect(software_license_policy.custom_software_license_id).to eq(custom_software_license.id)

      perform_migration

      software_license_policy.reload

      expect(software_license_policy.software_license_id).to be_nil
      expect(software_license_policy.software_license_spdx_identifier).to be_nil
      expect(software_license_policy.custom_software_license_id).to eq(custom_software_license.id)
    end
  end
end
