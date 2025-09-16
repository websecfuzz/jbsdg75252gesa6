# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, :with_merge_request_pipeline, source_project: project) }
  let_it_be(:pipeline) { merge_request.all_pipelines.last }

  subject(:perform) { described_class.new.perform(pipeline.id, merge_request.id) }

  describe "#perform" do
    it "updates approvals" do
      expect_next_instance_of(Security::ScanResultPolicies::UpdateApprovalsService, merge_request: merge_request,
        pipeline: pipeline) do |service|
        expect(service).to receive(:execute)
      end

      perform
    end
  end
end
