# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::ExclusionsManager, feature_category: :secret_detection do
  include_context 'secrets check context'

  let(:audit_logger) { instance_double(Gitlab::Checks::SecretPushProtection::AuditLogger) }
  let(:exclusions_manager) { described_class.new(project: project, changes_access: changes_access) }

  before do
    allow(exclusions_manager).to receive(:audit_logger).and_return(audit_logger)
    allow(audit_logger).to receive(:log_exclusion_audit_event)
  end

  describe 'active exclusions' do
    context 'when exclusion is based on matching a file path' do
      let!(:path_exclusion1) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: 'file-exclusion-1.rb')
      end

      let!(:path_exclusion2) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: 'spec/**/*.rb')
      end

      it 'includes them in active_exclusions[:path]' do
        exclusions = exclusions_manager.active_exclusions
        expect(exclusions[:path].map(&:value)).to contain_exactly(path_exclusion1.value, path_exclusion2.value)
      end
    end

    context 'when exclusion is based on matching a rule from the default ruleset' do
      let!(:rule_exclusion) do
        create(:project_security_exclusion, :active, :with_rule, project: project,
          value: 'gitlab_personal_access_token')
      end

      it 'includes them in active_exclusions[:rule]' do
        exclusions = exclusions_manager.active_exclusions
        expect(exclusions[:rule].map(&:value)).to contain_exactly(rule_exclusion.value)
      end
    end

    context 'when exclusion is based on matching a raw value or string' do
      let!(:raw_value_exclusion) do
        create(:project_security_exclusion, :active, :with_raw_value, project: project, value: 'glpat-0123456789')
      end

      it 'includes them in active_exclusions[:raw_value]' do
        exclusions = exclusions_manager.active_exclusions
        expect(exclusions[:raw_value].map(&:value)).to contain_exactly(raw_value_exclusion.value)
      end
    end
  end

  describe '#matches_excluded_path?' do
    context 'when path exclusion is set' do
      let!(:path_exclusion) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: '*.rb')
      end

      it 'returns true for matching paths and logs an event' do
        expect(exclusions_manager.matches_excluded_path?('test.rb')).to be(true)
        expect(audit_logger).to have_received(:log_exclusion_audit_event)
          .with(have_attributes(type: 'path', value: '*.rb'))
      end

      it 'returns false for non-matching paths and does not log' do
        expect(exclusions_manager.matches_excluded_path?('test.md')).to be(false)
        expect(audit_logger).not_to have_received(:log_exclusion_audit_event)
      end
    end

    context 'when multiple path exclusions exist' do
      before do
        stub_const('::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT', 2)
      end

      let!(:exclusion1) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: '*.rb')
      end

      let!(:exclusion2) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: '*.md')
      end

      it 'returns true if any single exclusion matches' do
        expect(exclusions_manager.matches_excluded_path?('README.md')).to be(true)
        expect(audit_logger).to have_received(:log_exclusion_audit_event).with(have_attributes(type: 'path',
          value: '*.md'))
      end
    end

    context 'when path is deeper than MAX_PATH_EXCLUSIONS_DEPTH' do
      let!(:path_exclusion) do
        create(:project_security_exclusion, :active, :with_path, project: project, value: '*.rb')
      end

      let(:very_deep_path) { "#{'nested/' * 21}somefile.rb" }

      it 'returns false without logging' do
        expect(exclusions_manager.matches_excluded_path?(very_deep_path)).to be(false)
        expect(audit_logger).not_to have_received(:log_exclusion_audit_event)
      end
    end

    context 'when path exclusions exceed the MAX_PATH_EXCLUSIONS_PER_PROJECT limit' do
      before do
        stub_const('::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT', 1)

        mock_exclusions = [
          build_stubbed(:project_security_exclusion, :active, :with_path, project: project, value: '*.rb'),
          build_stubbed(:project_security_exclusion, :active, :with_path, project: project, value: '*.md')
        ]

        allow(exclusions_manager).to receive(:active_exclusions).and_return({ path: mock_exclusions })
      end

      it 'checks only up to the limit and returns false for a path matching the second item' do
        expect(File).to receive(:fnmatch?).with('*.rb', 'README.md', any_args).and_return(false)

        expect(exclusions_manager.matches_excluded_path?('README.md')).to be(false)
        expect(audit_logger).not_to have_received(:log_exclusion_audit_event)
      end
    end
  end

  describe '.exclusion_type' do
    it 'maps known keys to their GRPC enum' do
      expect(described_class.exclusion_type('path')).to eq(
        ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_PATH
      )
      expect(described_class.exclusion_type(:rule)).to eq(
        ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RULE
      )
    end

    it 'returns unknown enum for unrecognized keys' do
      expect(described_class.exclusion_type('bogus')).to eq(
        ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_UNSPECIFIED
      )
    end
  end
end
