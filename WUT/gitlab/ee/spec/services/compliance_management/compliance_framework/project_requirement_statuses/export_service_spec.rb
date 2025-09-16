# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService,
  feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, name: "Test Project", namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, name: 'Test Framework', namespace: group) }
  let_it_be(:requirement1) { create(:compliance_requirement, name: 'First Requirement', framework: framework) }
  let_it_be(:requirement2) { create(:compliance_requirement, name: 'Second Requirement', framework: framework) }
  let_it_be(:requirement3) { create(:compliance_requirement, name: 'Third Requirement', framework: framework) }

  let(:status1) do
    create(:project_requirement_compliance_status,
      pass_count: 2,
      fail_count: 0,
      pending_count: 1,
      project_id: project.id,
      compliance_requirement: requirement1,
      compliance_framework: framework
    )
  end

  let(:status2) do
    create(:project_requirement_compliance_status,
      pass_count: 0,
      fail_count: 3,
      pending_count: 0,
      project_id: project.id,
      compliance_requirement: requirement2,
      compliance_framework: framework
    )
  end

  subject(:service) { described_class.new(user: user, group: group) }

  describe '#execute' do
    context 'with insufficient permissions' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_compliance_adherence_report, group).and_return(false)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Access to group denied for user with ID: #{user.id}")
      end
    end

    context 'when parameter is not a group' do
      let(:user_namespace) { create(:namespace, owner: user) }
      let(:invalid_service) { described_class.new(user: user, group: user_namespace) }

      it 'returns an error response' do
        result = invalid_service.execute

        expect(result).to be_error
        expect(result.message).to eq('namespace must be a group')
      end
    end

    context 'with valid permissions' do
      before_all do
        group.add_owner(user)
      end

      before do
        stub_licensed_features(group_level_compliance_adherence_report: true)

        finder = instance_double(ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder)
        allow(ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder)
          .to receive(:new)
                .with(group, user)
                .and_return(finder)
        allow(finder).to receive(:execute).and_return([status1, status2])
      end

      it 'returns a successful response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to be_a(String)
      end

      it 'generates header row correctly' do
        result = service.execute
        csv = CSV.parse(result.payload)
        header = csv[0]

        expected_header = [
          "Passed", "Failed", "Pending", "Requirement",
          "Framework", "Project ID", "Project name", "Date of last update"
        ]

        expect(header).to match_array(expected_header)
      end

      it 'generates rows with the correct data', :aggregate_failures do
        result = service.execute
        csv = CSV.parse(result.payload)

        headers = csv[0]
        rows = csv[1..].map do |row|
          headers.zip(row).to_h
        end

        expect(rows[0]["Passed"]).to eq(status1.pass_count.to_s)
        expect(rows[0]["Failed"]).to eq(status1.fail_count.to_s)
        expect(rows[0]["Pending"]).to eq(status1.pending_count.to_s)
        expect(rows[0]["Requirement"]).to eq(status1.compliance_requirement.name)
        expect(rows[0]["Framework"]).to eq(status1.compliance_framework.name)
        expect(rows[0]["Project ID"]).to eq(status1.project_id.to_s)
        expect(rows[1]["Project name"]).to eq(status1.project.name)
        expect(rows[0]["Date of last update"]).to eq(status1.updated_at.to_s)

        expect(rows[1]["Passed"]).to eq(status2.pass_count.to_s)
        expect(rows[1]["Failed"]).to eq(status2.fail_count.to_s)
        expect(rows[1]["Pending"]).to eq(status2.pending_count.to_s)
        expect(rows[1]["Requirement"]).to eq(status2.compliance_requirement.name)
        expect(rows[1]["Framework"]).to eq(status2.compliance_framework.name)
        expect(rows[1]["Project ID"]).to eq(status2.project_id.to_s)
        expect(rows[1]["Project name"]).to eq(status2.project.name)
        expect(rows[1]["Date of last update"]).to eq(status2.updated_at.to_s)
      end

      context 'with no status data' do
        before do
          finder = instance_double(ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder)
          allow(ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder)
            .to receive(:new)
                  .with(group, user)
                  .and_return(finder)
          allow(finder).to receive(:execute).and_return([])
        end

        it 'returns only the header row' do
          result = service.execute
          csv = CSV.parse(result.payload)

          expect(csv.length).to eq(1)
          expect(csv[0]).to match_array([
            "Passed", "Failed", "Pending", "Requirement",
            "Framework", "Project ID", "Project name", "Date of last update"
          ])
        end
      end
    end
  end

  describe '#email_export' do
    let(:worker_class) { ComplianceManagement::ComplianceFramework::ProjectRequirementStatusesExportMailerWorker }

    it 'enqueues the export mailer worker' do
      expect(worker_class).to receive(:perform_async).with(user.id, group.id)

      result = service.email_export

      expect(result).to be_success
    end
  end
end
