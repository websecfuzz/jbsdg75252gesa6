# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::RecalculateService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { project.namespace }
  let(:project_id) { project.id }
  let(:deleted_project) { false }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object and calls `execute`' do
      described_class.execute(group)

      expect(described_class).to have_received(:new).with(group)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    subject(:service) { described_class.new(group) }

    context 'when group is not present' do
      let(:group) { nil }

      it 'returns nil without performing any actions' do
        expect(service.execute).to be_nil
        expect(::Security::AnalyzerNamespaceStatuses::AdjustmentService).not_to receive(:new)
        expect(::Security::AnalyzerNamespaceStatuses::AncestorsUpdateService).not_to receive(:execute)
      end
    end

    context 'when recalculating analyzer namespace statuses' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: parent_group) }
      let_it_be(:project_1) { create(:project, group: sub_group) }
      let_it_be(:project_2) { create(:project, group: sub_group) }

      let!(:project_1_analyzer_statuses) do
        create(:analyzer_project_status, project: project_1, analyzer_type: :sast, status: :success)
        create(:analyzer_project_status, project: project_1, analyzer_type: :dast, status: :failed)
        create(:analyzer_project_status, project: project_1, analyzer_type: :api_fuzzing, status: :not_configured)
      end

      let!(:project_2_analyzer_statuses) do
        create(:analyzer_project_status, project: project_2, analyzer_type: :sast, status: :failed)
        create(:analyzer_project_status, project: project_2, analyzer_type: :dast, status: :failed)
        create(:analyzer_project_status, project: project_2, analyzer_type: :api_fuzzing, status: :success)
      end

      let!(:sub_group_analyzer_statuses) do
        create(:analyzer_namespace_status, namespace: sub_group, analyzer_type: :sast,
          success: 2, failure: 1) # extra 1 success so the recalculate service will have something to re-calculate
        create(:analyzer_namespace_status, namespace: sub_group, analyzer_type: :dast,
          success: 0, failure: 3) # extra 1 failure so the recalculate service will have something to re-calculate
        create(:analyzer_namespace_status, namespace: sub_group, analyzer_type: :api_fuzzing, success: 1, failure: 0)
      end

      let!(:parent_group_analyzer_statuses) do
        create(:analyzer_namespace_status, namespace: parent_group, analyzer_type: :sast, success: 2, failure: 1)
        create(:analyzer_namespace_status, namespace: parent_group, analyzer_type: :dast, success: 0, failure: 3)
        create(:analyzer_namespace_status, namespace: parent_group, analyzer_type: :api_fuzzing, success: 1, failure: 0)
      end

      subject(:recalculate_service) do
        described_class.execute(sub_group)
      end

      it 'updates ancestors with new counters' do
        recalculate_service

        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: sub_group.id, analyzer_type: "sast")
          .attributes).to include({ "success" => 1, "failure" => 1 })
        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: sub_group.id, analyzer_type: "dast")
          .attributes).to include({ "success" => 0, "failure" => 2 })
        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: sub_group.id, analyzer_type: "api_fuzzing")
          .attributes).to include({ "success" => 1, "failure" => 0 })

        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: parent_group.id, analyzer_type: "sast")
          .attributes).to include({ "success" => 1, "failure" => 1 })
        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: parent_group.id, analyzer_type: "dast")
          .attributes).to include({ "success" => 0, "failure" => 2 })
        expect(Security::AnalyzerNamespaceStatus.find_by(namespace_id: parent_group.id, analyzer_type: "api_fuzzing")
          .attributes).to include({ "success" => 1, "failure" => 0 })
      end
    end
  end
end
