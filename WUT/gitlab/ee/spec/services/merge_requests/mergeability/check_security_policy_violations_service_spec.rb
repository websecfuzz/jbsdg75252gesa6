# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckSecurityPolicyViolationsService, feature_category: :code_review_workflow do
  subject(:check_policies) { described_class.new(merge_request: merge_request, params: params) }

  let(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:project) { create(:project, :repository) }
  let(:params) { { skip_security_policy_check: skip_check } }
  let(:skip_check) { false }

  it_behaves_like 'mergeability check service', :security_policy_violations,
    'Checks whether the security policies are satisfied'

  describe "#execute" do
    let(:result) { check_policies.execute }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'with no scan result policies' do
      it 'returns a check result with inactive status' do
        expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end

    context 'when scan result policy exists' do
      let(:policy) { create(:scan_result_policy_read, project: project) }

      before do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: policy, name: 'Policy 1')
      end

      context 'when policy_mergability_check is false' do
        before do
          stub_feature_flags(policy_mergability_check: false)
        end

        it 'returns a check result with inactive status' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when security_orchestration_policies license is false' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'returns a check result with inactive status' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when scan result violations are failed' do
        before do
          create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        context 'when the MR is not approved' do
          before do
            create(:report_approver_rule, merge_request: merge_request, approvals_required: 1, users: [create(:user)])
          end

          it "returns a check result with status failure" do
            expect(result.status)
              .to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
            expect(result.payload[:identifier]).to eq(:security_policy_violations)
          end
        end

        context 'when the MR is approved' do
          it "returns check result with status success" do
            expect(result.status)
              .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
          end
        end
      end

      context 'when no scan result violations exist' do
        it "returns check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context 'when scan result violations are running' do
        before do
          create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
        end
      end

      context 'when scan result violations are only warning' do
        before do
          create(:scan_result_policy_violation, :warn, project: project, merge_request: merge_request,
            scan_result_policy_read: policy, violation_data: nil)
        end

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end
    end
  end

  describe '#skip?' do
    subject { check_policies.skip? }

    context 'when skip check is true' do
      let(:skip_check) { true }

      it { is_expected.to eq true }
    end

    context 'when skip check is false' do
      let(:skip_check) { false }

      it { is_expected.to eq false }
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(check_policies.cacheable?).to eq false
    end
  end
end
