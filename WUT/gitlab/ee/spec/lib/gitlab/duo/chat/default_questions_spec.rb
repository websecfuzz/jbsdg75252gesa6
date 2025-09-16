# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Duo::Chat::DefaultQuestions, feature_category: :duo_chat do
  describe "#execute" do
    subject { described_class.new(user, url: url, resource: resource).execute }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let(:url) { nil }

    context "with allowed resource" do
      before do
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      context "with issue resource" do
        let(:resource) { ::Ai::AiResource::Issue.new(user, build_stubbed(:issue)) }

        it { is_expected.to include("What key decisions were made in this issue?") }
      end

      context "with merge request resource" do
        let(:resource) { ::Ai::AiResource::MergeRequest.new(user, build_stubbed(:merge_request)) }

        it { is_expected.to include("What changed in this diff?") }
      end

      context "with ci job resource" do
        let(:resource) { ::Ai::AiResource::Ci::Build.new(user, build_stubbed(:ci_build)) }

        it { is_expected.to include("What was each stage's final status?") }
      end

      context "with epic resource" do
        let(:resource) { ::Ai::AiResource::Epic.new(user, build_stubbed(:epic)) }

        it { is_expected.to include("What key features are planned?") }
      end

      context "with commit resource" do
        let(:resource) { ::Ai::AiResource::Commit.new(user, build_stubbed(:commit)) }

        it { is_expected.to include("How can I test these changes?") }
      end
    end

    context "without allowed resource" do
      let(:resource) { ::Ai::AiResource::Issue.new(user, build_stubbed(:issue)) }

      it "returns default questions" do
        is_expected.to include("How do I estimate story points?")
      end
    end

    context "with code url" do
      let(:url) { Gitlab::Routing.url_helpers.project_blob_url(project, 'readme.md') }
      let(:resource) { nil }

      it { is_expected.to include("What does this code do?") }
    end

    context "with random url" do
      let(:url) { Gitlab::Routing.url_helpers.project_url(project) }
      let(:resource) { nil }

      it "returns default questions" do
        is_expected.to include("How do I estimate story points?")
      end
    end
  end
end
