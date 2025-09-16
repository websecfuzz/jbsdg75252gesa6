# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillSoftwareLicensePolicies, feature_category: :security_policy_management do
  let(:software_licenses) { table(:software_licenses) }
  let(:custom_software_licenses) { table(:custom_software_licenses) }
  let(:software_license_policies) { table(:software_license_policies) }
  let(:organizations) { table(:organizations) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }

  let!(:organization) { organizations.create!(name: 'organization', path: 'organization') }
  let!(:namespace) { namespaces.create!(name: 'namespace', path: 'namespace', organization_id: organization.id) }
  let!(:software_license) { software_licenses.create!(name: 'MIT License', spdx_identifier: 'MIT') }
  let(:software_license_id) { software_license.id }
  let(:software_license_spdx_identifier) { nil }
  let(:custom_software_license_id) { nil }
  let!(:project) do
    projects.create!(namespace_id: namespace.id, project_namespace_id: namespace.id, organization_id: organization.id)
  end

  let!(:software_license_policy) do
    software_license_policies.create!(project_id: project.id,
      software_license_id: software_license_id,
      software_license_spdx_identifier: software_license_spdx_identifier,
      custom_software_license_id: custom_software_license_id)
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

  shared_examples 'does not create custom software licenses records' do
    it 'does not creates custom software licenses records' do
      expect { perform_migration }.not_to change { custom_software_licenses.count }
    end
  end

  shared_examples 'creates a new custom software license' do
    it 'creates a new custom software license' do
      expect { perform_migration }.to change { custom_software_licenses.count }.by(1)
    end
  end

  context 'when there are software_license_policies with software_license_spdx_identifier' do
    let(:software_license_spdx_identifier) { 'MIT' }

    it_behaves_like 'does not create custom software licenses records'
  end

  context 'when there are software_license_policies with custom_software_license_id' do
    let!(:custom_software_license) { custom_software_licenses.create!(name: 'Custom License', project_id: project.id) }
    let(:software_license_id) { nil }
    let(:custom_software_license_id) { custom_software_license.id }

    it_behaves_like 'does not create custom software licenses records'
  end

  context <<~DESCRIPTION do
    when there are software_license_policies
    without software_license_spdx_identifier
    and without custom_software_license_id
  DESCRIPTION
    context 'when the software license is in the SPDX catalog' do
      it_behaves_like 'does not create custom software licenses records'

      it 'sets the software_license_spdx_identifier' do
        expect { perform_migration }.to change {
          software_license_policy.reload.software_license_spdx_identifier
        }.from(nil).to('MIT')
      end
    end

    context 'when the software license is not in the SPDX catalog' do
      let!(:software_license) { software_licenses.create!(name: 'Custom License') }

      shared_examples_for 'sets the custom_software_license_id' do
        it 'sets the custom_software_license_id' do
          expect(software_license_policy.custom_software_license_id).to be_nil

          perform_migration

          custom_software_license = custom_software_licenses.last

          expect(software_license_policy.reload.custom_software_license_id).to eq(custom_software_license.id)
        end
      end

      context 'when a custom_software_license with the software_license name does not exist' do
        it 'does not sets the software_license_spdx_identifier' do
          expect { perform_migration }.not_to change {
            software_license_policy.reload.software_license_spdx_identifier
          }.from(nil)
        end

        it_behaves_like 'creates a new custom software license'
        it_behaves_like 'sets the custom_software_license_id'
      end

      context 'when a custom_software_license with the software_license name exist' do
        let!(:custom_software_license) do
          custom_software_licenses.create!(name: 'Custom License', project_id: project_id)
        end

        context 'when the custom_software_license is associated to another project' do
          let!(:other_organization) { organizations.create!(name: 'other organization', path: 'other organization') }
          let!(:other_namespace) do
            namespaces.create!(name: 'other namespace', path: 'other namespace', organization_id: organization.id)
          end

          let!(:other_project) do
            projects.create!(namespace_id: other_namespace.id, project_namespace_id: other_namespace.id,
              organization_id: other_organization.id)
          end

          let(:project_id) { other_project.id }

          it_behaves_like 'creates a new custom software license'
          it_behaves_like 'sets the custom_software_license_id'
        end

        context 'when the custom_software_license is associated to the same project' do
          let(:project_id) { project.id }

          it_behaves_like 'does not create custom software licenses records'
          it_behaves_like 'sets the custom_software_license_id'
        end
      end
    end
  end
end
