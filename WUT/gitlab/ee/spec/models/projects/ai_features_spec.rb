# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AiFeatures, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }

  subject(:ai_features) { described_class.new(project) }

  describe '#ai_review_merge_request_allowed?' do
    let_it_be(:current_user) { create(:user, developer_of: project) }

    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    subject(:ai_review_merge_request_allowed?) { ai_features.review_merge_request_allowed?(current_user) }

    before do
      stub_licensed_features(review_merge_request: true)
      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
    end

    context "when feature is authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(true)
      end

      it { is_expected.to be(false) }

      context 'when user has permission' do
        before do
          allow(Ability).to receive(:allowed?).with(current_user, :access_ai_review_mr, project).and_return(true)
        end

        it { is_expected.to be(true) }
      end

      context 'when license is not set' do
        before do
          stub_licensed_features(review_merge_request: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context "when feature is not authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end
end
