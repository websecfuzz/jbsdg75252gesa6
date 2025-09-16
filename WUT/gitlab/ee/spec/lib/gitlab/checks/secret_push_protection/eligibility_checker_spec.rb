# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::EligibilityChecker, feature_category: :secret_detection do
  include_context 'secrets check context'

  let(:validator) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  describe '#should_scan?' do
    shared_examples 'skips the push check' do
      it 'returns false' do
        expect(validator.should_scan?).to be(false)
      end
    end

    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: false)
      end

      it_behaves_like 'skips the push check'
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
      end

      context 'when project setting is disabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: false)
        end

        it_behaves_like 'skips the push check'
      end

      context 'when project setting is enabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: true)
        end

        context 'when license is not ultimate' do
          it_behaves_like 'skips the push check'
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(secret_push_protection: true)
          end

          context 'when this commit is deleting the branch' do
            let(:changes) do
              [
                { oldrev: new_commit, newrev: Gitlab::Git::SHA1_BLANK_SHA, ref: 'refs/heads/deleteme' }
              ]
            end

            it_behaves_like 'skips the push check'
          end

          context 'when commit message contains skip flag' do
            let_it_be(:new_commit) do
              create_commit(
                { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' }, # gitleaks:allow
                'skip scan [skip secret push protection]'
              )
            end

            it_behaves_like 'skips the push check'
          end

          context 'when push option skips secret detection' do
            let(:changes_access) do
              ::Gitlab::Checks::ChangesAccess.new(
                changes,
                project: project,
                user_access: user_access,
                protocol: protocol,
                logger: logger,
                push_options: ::Gitlab::PushOptions.new(["secret_push_protection.skip_all"]),
                gitaly_context: gitaly_context
              )
            end

            it_behaves_like 'skips the push check'
          end

          context 'when all checks pass' do
            it 'returns true' do
              expect(validator.should_scan?).to be(true)
            end
          end
        end
      end
    end
  end
end
