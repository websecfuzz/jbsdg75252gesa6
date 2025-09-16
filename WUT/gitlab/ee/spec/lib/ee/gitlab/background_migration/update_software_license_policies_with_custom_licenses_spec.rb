# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::UpdateSoftwareLicensePoliciesWithCustomLicenses, feature_category: :security_policy_management do
  let(:software_licenses_table) { table(:software_licenses) }
  let(:custom_software_licenses_table) { table(:custom_software_licenses) }
  let(:software_license_policies_table) { table(:software_license_policies) }
  let(:projects_table) { table(:projects) }
  let(:namespace_table) { table(:namespaces) }
  let(:organizations_table) { table(:organizations) }

  let(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
  let!(:namespace) { namespace_table.create!(name: 'namespace', path: 'namespace', organization_id: organization.id) }
  let!(:project) do
    projects_table.create!(namespace_id: namespace.id, project_namespace_id: namespace.id,
      organization_id: organization.id)
  end

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

  context 'with policies linked to software licenses' do
    let!(:software_license_policy) do
      software_license_policies_table.create!(project_id: project.id, software_license_id: software_license_id)
    end

    context 'with spdx_identifier' do
      let!(:software_license_with_spdx) { software_licenses_table.create!(name: 'MIT License', spdx_identifier: 'MIT') }
      let(:software_license_id) { software_license_with_spdx.id }

      it 'does not update the software_license_id' do
        expect(software_license_policy.software_license_id).to eq(software_license_with_spdx.id)

        perform_migration

        expect(software_license_policy.reload.software_license_id).to eq(software_license_with_spdx.id)
      end
    end

    context 'without spdx_identifier' do
      let(:custom_license_name) { 'Custom License' }
      let!(:software_license_without_spdx) { software_licenses_table.create!(name: 'Custom License') }
      let!(:custom_software_license) do
        custom_software_licenses_table.create!(name: custom_license_name, project_id: project.id)
      end

      let(:software_license_id) { software_license_without_spdx.id }

      it 'keeps the software_license_id and updates custom_software_license_id' do
        expect(software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
        expect(software_license_policy.custom_software_license_id).to be_nil

        perform_migration

        software_license_policy.reload

        expect(software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
        expect(software_license_policy.custom_software_license_id).to eq(custom_software_license.id)
      end

      context 'when linked to software licenses policies of different projects' do
        let(:other_organization) { organizations_table.create!(name: 'other organization', path: 'other organization') }
        let!(:other_namespace) do
          namespace_table.create!(name: 'other namespace', path: 'other namespace',
            organization_id: other_organization.id)
        end

        let!(:other_project) do
          projects_table.create!(namespace_id: other_namespace.id, project_namespace_id: other_namespace.id,
            organization_id: other_organization.id)
        end

        let!(:other_custom_software_license) do
          custom_software_licenses_table.create!(name: custom_license_name, project_id: other_project.id)
        end

        let!(:other_software_license_policy) do
          software_license_policies_table.create!(project_id: other_project.id,
            software_license_id: software_license_without_spdx.id)
        end

        it 'keeps the software_license_id and updates the custom_software_license_id for both policies' do
          expect(software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
          expect(software_license_policy.custom_software_license_id).to be_nil

          expect(other_software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
          expect(other_software_license_policy.custom_software_license_id).to be_nil

          perform_migration

          software_license_policy.reload
          other_software_license_policy.reload

          expect(software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
          expect(software_license_policy.custom_software_license_id).to eq(custom_software_license.id)

          expect(other_software_license_policy.software_license_id).to eq(software_license_without_spdx.id)
          expect(other_software_license_policy.custom_software_license_id).to eq(other_custom_software_license.id)
        end
      end
    end
  end
end
