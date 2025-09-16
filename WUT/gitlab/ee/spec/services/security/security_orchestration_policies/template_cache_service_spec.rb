# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::TemplateCacheService, "#fetch", feature_category: :security_policy_management do
  let(:scan_type) { "sast" }
  let(:latest) { false }

  subject(:fetch) { described_class.new.fetch(scan_type, latest: latest) }

  Security::SecurityOrchestrationPolicies::CiAction::Template::SCAN_TEMPLATES.each_key do |template|
    context template.to_s do
      let(:scan_type) { template }

      it { is_expected.to be_a(Hash).and satisfy(&:any?) }

      context "when fetching latest template" do
        let(:latest) { true }

        it { is_expected.to be_a(Hash).and satisfy(&:any?) }
      end
    end
  end

  describe "cache misses" do
    it "instantiates" do
      expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: "Jobs/SAST").and_call_original

      fetch
    end

    context "when cache matches `scan_type` but not `latest`" do
      before do
        described_class.new.fetch(scan_type, latest: !latest)
      end

      it "instantiates" do
        expect(::TemplateFinder).to receive(:build).and_call_original

        fetch
      end
    end

    context "when fetching latest template" do
      let(:latest) { true }

      it "instantiates" do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil,
          name: "Jobs/SAST.latest").and_call_original

        fetch
      end
    end
  end

  describe "cache hits" do
    before do
      fetch
    end

    it "does not instantiate" do
      expect(::TemplateFinder).not_to receive(:build)

      fetch
    end
  end
end
