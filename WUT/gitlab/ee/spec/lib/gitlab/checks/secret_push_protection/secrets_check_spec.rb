# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::SecretsCheck, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:secrets_check) { described_class.new(changes_access) }

  describe '#validate!' do
    context 'when secret_detection_enable_spp_for_public_projects is disabled' do
      before do
        stub_feature_flags(secret_detection_enable_spp_for_public_projects: false)
      end

      context 'when project is public' do
        before do
          project.update!(visibility_level: Project::PUBLIC)
        end

        context 'when project does not have feature license' do
          before do
            stub_licensed_features(secret_push_protection: false)
          end

          it_behaves_like 'does not call SDS'
        end
      end
    end

    context 'when project is private' do
      before do
        project.update!(visibility_level: Project::PRIVATE)
      end

      context 'when project has not opted in to SPP' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: false)
        end

        it_behaves_like 'does not call SDS'
        it_behaves_like 'skips the push check'
      end

      context 'when project has opted in to SPP' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: true)
        end

        context 'when project does not have feature license' do
          before do
            stub_licensed_features(secret_push_protection: false)
          end

          it_behaves_like 'does not call SDS'
          it_behaves_like 'skips the push check'
        end
      end
    end

    context 'when project is public' do
      before do
        project.update!(visibility_level: Project::PUBLIC)
      end

      context 'when project has opted in to SPP' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: true)
        end

        context 'when project does not have feature license' do
          before do
            stub_licensed_features(secret_push_protection: false)
          end

          it_behaves_like 'calls SDS'
          it_behaves_like 'skips the push check'
        end

        context 'when project does have feature license' do
          before do
            Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
            stub_licensed_features(secret_push_protection: true)
          end

          it_behaves_like 'diff scan passed'
        end
      end

      context 'when project has not opted in to SPP' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: false)
        end

        context 'when payloads are empty' do
          before do
            allow_next_instance_of(Gitlab::Checks::SecretPushProtection::PayloadProcessor) do |instance|
              allow(instance).to receive(:standardize_payloads).and_return(nil)
            end
          end

          it_behaves_like 'does not call SDS'
          it_behaves_like 'skips the push check'
        end

        context 'when project does not have feature license' do
          before do
            stub_licensed_features(secret_push_protection: false)
          end

          it_behaves_like 'calls SDS'
          it_behaves_like 'skips the push check'
        end

        context 'when project does have feature license' do
          before do
            stub_licensed_features(secret_push_protection: true)
          end

          it_behaves_like 'calls SDS'
          it_behaves_like 'skips the push check'
        end
      end
    end

    context 'when project is private has ultimate access and has opted in' do
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

            context 'when SDS should be called (on SaaS)' do
              before do
                stub_saas_features(secret_detection_service: true)
                stub_application_setting(secret_detection_service_url: 'https://example.com')
              end

              context 'when instance is Dedicated (temporarily not using SDS)' do
                before do
                  stub_application_setting(gitlab_dedicated_instance: true)
                end

                it_behaves_like 'skips sending requests to the SDS' do
                  let(:is_dedicated) { true }
                end
              end

              context 'when instance is GitLab.com' do
                it_behaves_like 'skips sending requests to the SDS'

                context 'when `use_secret_detection_service` feature flag is enabled' do
                  # this is the happy path (as FFs are enabled by default)
                  it_behaves_like 'sends requests to the SDS' do
                    let(:sds_ff_enabled) { true }

                    before do
                      stub_feature_flags(use_secret_detection_service: true)
                    end
                  end
                end
              end
            end

            context 'when SDS should not be called (Self-Managed)' do
              it_behaves_like 'skips sending requests to the SDS' do
                let(:saas_feature_enabled) { false }
              end
            end

            context 'when deleting the branch' do
              # We instantiate the described class with delete_changes_access object to ensure
              # this spec example works as it uses repository.blank_ref to denote a branch deletion.
              subject(:secrets_check) { described_class.new(delete_changes_access) }

              it_behaves_like 'skips the push check'
            end

            context 'when scanning diffs' do
              it_behaves_like 'diff scan passed'
              it_behaves_like 'scan detected secrets in diffs'
              it_behaves_like 'detects secrets with special characters in diffs'
              it_behaves_like 'processes hunk headers'
              it_behaves_like 'scan detected secrets but some errors occured'
              it_behaves_like 'scan timed out'
              it_behaves_like 'scan failed to initialize'
              it_behaves_like 'scan failed with invalid input'
              it_behaves_like 'scan skipped due to invalid status'
              it_behaves_like 'scan skipped when a commit has special bypass flag'
              it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
              it_behaves_like 'scan discarded secrets because they match exclusions'

              it 'tracks and recovers errors when getting diff' do
                expect(repository).to receive(:diff_blobs).and_raise(::GRPC::InvalidArgument)
                expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(::GRPC::InvalidArgument))
                expect(secret_detection_logger).to receive(:error)
                  .once
                  .with(
                    hash_including(
                      "message" => error_messages[:invalid_input_error],
                      "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
                    )
                  )

                allow(secret_detection_logger).to receive(:info)
                expect { secrets_check.validate! }.not_to raise_error
              end

              context 'when the protocol is web' do
                subject(:secrets_check) { described_class.new(changes_access_web) }

                context 'when changes_access.gitaly_context enable_secrets_check is false' do
                  it_behaves_like 'skips the push check'
                end

                context 'when changes_access.gitaly_context enable_secrets_check is true' do
                  subject(:secrets_check) { described_class.new(changes_access_web_secrets_check_enabled) }

                  it_behaves_like 'diff scan passed'
                  it_behaves_like 'scan detected secrets in diffs'
                  it_behaves_like 'detects secrets with special characters in diffs'
                end
              end
            end
          end
        end
      end
    end
  end
end
