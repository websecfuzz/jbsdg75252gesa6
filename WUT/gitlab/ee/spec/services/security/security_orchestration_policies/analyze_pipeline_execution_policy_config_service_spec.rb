# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService, feature_category: :security_policy_management do
  let(:service) { described_class.new(project: project, current_user: user, params: { content: content }) }
  let_it_be(:project) { create(:project, :empty_repo) }
  let_it_be(:user) { create(:user) }
  let(:content) do
    {
      include: [
        { template: 'Jobs/Secret-Detection.gitlab-ci.yml' },
        { template: 'Jobs/Dependency-Scanning.gitlab-ci.yml' }
      ]
    }
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    it 'extracts scanners by the declared artifacts:reports' do
      expect(execute).to be_success
      expect(execute.payload).to eq(%w[secret_detection dependency_scanning])
    end

    context 'when a job with artifacts is declared manually' do
      let(:content) do
        {
          stages: ['test'],
          secrets: {
            script: 'script',
            artifacts: {
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            }
          }
        }
      end

      it 'extracts scanners by the declared artifacts:reports' do
        expect(execute).to be_success
        expect(execute.payload).to eq(%w[secret_detection])
      end
    end

    context 'when multiple jobs declare the same artifacts' do
      let(:content) do
        {
          include: [
            { template: 'Jobs/Secret-Detection.gitlab-ci.yml' }
          ],
          secrets: {
            script: 'script',
            artifacts: {
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            }
          }
        }
      end

      it 'extracts scanners without duplicates' do
        expect(execute).to be_success
        expect(execute.payload).to eq(%w[secret_detection])
      end
    end

    context 'when a job declares unsupported report_type' do
      let(:content) do
        {
          secret_detection: {
            script: 'script',
            artifacts: {
              reports: {
                cyclonedx: 'cyclonedx.json'
              }
            }
          }
        }
      end

      it 'returns an empty array' do
        expect(execute).to be_success
        expect(execute.payload).to be_empty
      end
    end

    context 'when content is invalid' do
      let(:content) do
        { invalid_job: {} }
      end

      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message)
          .to include(
            'Error occurred while parsing the CI configuration',
            'jobs config should contain at least one visible job'
          )
        expect(execute.payload).to be_empty
      end
    end

    context 'when error occurs while parsing the config' do
      let(:content) do
        {
          include: [{ project: 'invalid', file: 'invalid.yml' }]
        }
      end

      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message).to include('Project `invalid` not found or access denied!')
        expect(execute.payload).to be_empty
      end
    end
  end
end
