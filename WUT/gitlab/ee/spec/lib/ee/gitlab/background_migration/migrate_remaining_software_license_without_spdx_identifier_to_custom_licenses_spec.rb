# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::MigrateRemainingSoftwareLicenseWithoutSpdxIdentifierToCustomLicenses, feature_category: :security_policy_management do
  let(:software_licenses_table) { table(:software_licenses) }
  let(:custom_software_licenses_table) { table(:custom_software_licenses) }
  let(:software_license_policies_table) { table(:software_license_policies) }
  let(:organizations_table) { table(:organizations) }
  let(:projects_table) { table(:projects) }
  let(:namespace_table) { table(:namespaces) }

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

  shared_examples 'does not create custom software licenses records' do
    it 'does not creates custom software licenses records' do
      expect { perform_migration }.not_to change { custom_software_licenses_table.count }
    end
  end

  shared_examples 'creates new software licenses records' do |number_of_new_records:|
    it 'creates new custom software licenses records' do
      expect { perform_migration }.to change { custom_software_licenses_table.count }.by(number_of_new_records)
    end
  end

  context 'when there are software licenses without spdx_identifier' do
    let!(:software_licenses_without_spdx) { software_licenses_table.create!(name: 'Custom License') }

    context 'when the software licenses is linked to a software license policy' do
      let!(:organization) { organizations_table.create!(name: 'organization', path: 'organization') }
      let!(:namespace) do
        namespace_table.create!(name: 'namespace', path: 'namespace', organization_id: organization.id)
      end

      let!(:project) do
        projects_table.create!(
          namespace_id: namespace.id,
          project_namespace_id: namespace.id,
          organization_id: organization.id
        )
      end

      let!(:software_license_policy) do
        software_license_policies_table.create!(project_id: project.id,
          software_license_id: software_licenses_without_spdx.id)
      end

      it_behaves_like 'creates new software licenses records', number_of_new_records: 1

      it 'creates a new custom software license record with the correct attributes' do
        perform_migration

        expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name,
          project_id: project.id).count).to eq(1)
      end

      context 'when the same software license is linked to software license policies from different projects' do
        let!(:organization_2) { organizations_table.create!(name: 'organization 2', path: 'organization 2') }
        let!(:namespace_2) do
          namespace_table.create!(name: 'namespace 2', path: 'namespace 2', organization_id: organization.id)
        end

        let!(:project_2) do
          projects_table.create!(namespace_id: namespace_2.id, project_namespace_id: namespace_2.id,
            organization_id: organization.id)
        end

        let!(:software_license_policy_2) do
          software_license_policies_table.create!(project_id: project_2.id,
            software_license_id: software_licenses_without_spdx.id)
        end

        it_behaves_like 'creates new software licenses records', number_of_new_records: 2

        it 'creates new custom software license records with the correct attributes' do
          perform_migration

          expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name).count).to eq(2)
          expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name,
            project_id: project.id).count).to eq(1)
          expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name,
            project_id: project_2.id).count).to eq(1)
        end
      end

      context 'when a project contains multiple software licenses' do
        let!(:other_software_licenses_without_spdx) { software_licenses_table.create!(name: 'Other Custom License') }

        let!(:other_software_license_policy) do
          software_license_policies_table.create!(project_id: project.id,
            software_license_id: other_software_licenses_without_spdx.id)
        end

        it_behaves_like 'creates new software licenses records', number_of_new_records: 2

        it 'creates the new custom software license records with the correct attributes' do
          perform_migration

          expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name).count).to eq(1)
          expect(custom_software_licenses_table.where(name: other_software_licenses_without_spdx.name).count).to eq(1)

          expect(custom_software_licenses_table.where(name: software_licenses_without_spdx.name,
            project_id: project.id).count).to eq(1)
          expect(custom_software_licenses_table.where(name: other_software_licenses_without_spdx.name,
            project_id: project.id).count).to eq(1)
        end
      end

      context 'when the custom software license was already migrated' do
        let!(:custom_software_license) do
          custom_software_licenses_table.create!(name: 'Custom License',
            project_id: project.id)
        end

        it_behaves_like 'does not create custom software licenses records'
      end
    end

    context 'when the software licenses are not linked to a software license policy' do
      it_behaves_like 'does not create custom software licenses records'
    end
  end

  context 'when there are no software licenses without spdx_identifier' do
    it_behaves_like 'does not create custom software licenses records'
  end
end
