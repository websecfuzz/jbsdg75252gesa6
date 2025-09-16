# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckApprovedService, feature_category: :code_review_workflow do
  subject(:check_approved) { described_class.new(merge_request: merge_request, params: params) }

  let_it_be(:merge_request) { build(:merge_request) }
  let(:params) { { skip_approved_check: skip_check } }
  let(:skip_check) { false }

  it_behaves_like 'mergeability check service', :not_approved, 'Checks whether the merge request is approved'

  describe "#execute" do
    let(:result) { check_approved.execute }

    before do
      allow(merge_request)
        .to receive(:approval_feature_available?)
        .and_return(approval_feature_available?)
    end

    context 'when approval feature is available' do
      let(:approval_feature_available?) { true }

      before do
        allow(merge_request).to receive(:approved?).and_return(approved)
      end

      context 'when the merge request is temporarily unapproved' do
        let(:approved) { true }

        before do
          allow(merge_request).to receive(:temporarily_unapproved?).and_return(true)
        end

        it "returns a check result with status checking" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::CHECKING_STATUS
        end
      end

      context "when the merge request is approved" do
        let(:approved) { true }

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context "when the merge request is not approved" do
        let(:approved) { false }

        it "returns a check result with status failure" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
          expect(result.payload[:identifier]).to eq(:not_approved)
        end
      end
    end

    context 'when approval feature is not available' do
      let(:approval_feature_available?) { false }

      it 'returns a check result with inactive status' do
        expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end
  end

  describe '#skip?' do
    subject { check_approved.skip? }

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
      expect(check_approved.cacheable?).to eq false
    end
  end
end
