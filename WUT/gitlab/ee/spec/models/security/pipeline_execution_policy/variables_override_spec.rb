# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::VariablesOverride, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:variables_override) { described_class.new(project: project, job_options: job_options) }

  describe '#apply_highest_precedence' do
    subject { variables_override.apply_highest_precedence(variables, yaml_variables).to_runner_variables }

    let(:variables) do
      Gitlab::Ci::Variables::Collection.new([
        { key: 'SAST_DISABLED', value: 'true' },
        { key: 'SECRET_DETECTION_DISABLED', value: 'true' }
      ])
    end

    let(:yaml_variables) do
      Gitlab::Ci::Variables::Collection.new([{ key: 'SAST_DISABLED', value: 'false' }])
    end

    let(:expected_original_variables) do
      [
        { key: 'SAST_DISABLED', value: 'true', public: true, masked: false },
        { key: 'SECRET_DETECTION_DISABLED', value: 'true', public: true, masked: false }
      ]
    end

    context 'without `execution_policy_job` option' do
      let(:job_options) { {} }

      it { is_expected.to eq expected_original_variables }
    end

    context 'with other options' do
      let(:job_options) { { another_option: true } }

      it { is_expected.to eq expected_original_variables }
    end

    context 'with `execution_policy_job` option' do
      let(:job_options) { { execution_policy_job: true } }
      let(:expected_enforced_variables) do
        [
          { key: 'SECRET_DETECTION_DISABLED', value: 'true', public: true, masked: false },
          { key: 'SAST_DISABLED', value: 'false', public: true, masked: false }
        ]
      end

      it { is_expected.to eq expected_enforced_variables }

      context 'with `execution_policy_variables_override` option' do
        let(:job_options) { { execution_policy_job: true, execution_policy_variables_override: { allowed: false } } }

        it { is_expected.to eq expected_original_variables }
      end
    end
  end

  describe '#apply_variables_override' do
    subject { variables_override.apply_variables_override(variables).to_hash }

    let(:variables) { ::Gitlab::Ci::Variables::Collection.new([{ key: 'SAST_DISABLED', value: 'true' }]) }

    context 'without `execution_policy_variables_override` option' do
      let(:job_options) { {} }

      it { is_expected.to eq('SAST_DISABLED' => 'true') }
    end

    context 'with `execution_policy_variables_override` option but without `execution_policy_job` option' do
      let(:job_options) { { execution_policy_variables_override: { allowed: false } } }

      it { is_expected.to eq('SAST_DISABLED' => 'true') }
    end

    context 'with `execution_policy_variables_override` option' do
      let(:job_options) { { execution_policy_job: true, execution_policy_variables_override: override_option } }

      context 'when `execution_policy_variables_override` is allowed' do
        context 'without `exceptions`' do
          let(:override_option) { { allowed: true } }

          it { is_expected.to eq('SAST_DISABLED' => 'true') }
        end

        context 'with `exceptions`' do
          let(:override_option) { { allowed: true, exceptions: %w[SAST_DISABLED] } }

          context 'when matching' do
            it { is_expected.to eq({}) }
          end

          context 'when not matching' do
            let(:override_option) { { allowed: true, exceptions: %w[DAST_DISABLED] } }

            it { is_expected.to eq('SAST_DISABLED' => 'true') }
          end
        end
      end

      context 'when `execution_policy_variables_override` is disallowed' do
        context 'without `exceptions`' do
          let(:override_option) { { allowed: false } }

          it { is_expected.to eq({}) }
        end

        context 'with `exceptions`' do
          let(:override_option) { { allowed: false, exceptions: %w[SAST_DISABLED] } }

          context 'when matching' do
            it { is_expected.to eq('SAST_DISABLED' => 'true') }
          end

          context 'when not matching' do
            let(:override_option) { { allowed: false, exceptions: %w[DAST_DISABLED] } }

            it { is_expected.to eq({}) }
          end
        end
      end
    end
  end
end
