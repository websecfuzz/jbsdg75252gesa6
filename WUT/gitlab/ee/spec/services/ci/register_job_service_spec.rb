# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RegisterJobService, '#execute', feature_category: :continuous_integration do
  include ::Ci::MinutesHelpers

  let_it_be_with_refind(:shared_runner) { create(:ci_runner, :instance) }

  let!(:project_timeout) { 3699 }
  let!(:namespace) { create(:namespace) }
  let!(:project) do
    create(:project, shared_runners_enabled: true, namespace: namespace, build_timeout: project_timeout)
  end

  let!(:pipeline) { create(:ci_empty_pipeline, project: project) }
  let!(:pending_build) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

  shared_examples 'namespace minutes quota' do
    context 'shared runners minutes limit' do
      subject { described_class.new(shared_runner, nil).execute.build }

      shared_examples 'returns a build' do |runners_minutes_used|
        before do
          set_ci_minutes_used(project.namespace, runners_minutes_used)
        end

        it 'when in disaster recovery it ignores quota and returns anyway' do
          stub_feature_flags(ci_queueing_disaster_recovery_disable_quota: true)

          is_expected.to be_kind_of(Ci::Build)
        end

        it { is_expected.to be_kind_of(Ci::Build) }
      end

      shared_examples 'does not return a build' do |runners_minutes_used|
        before do
          set_ci_minutes_used(project.namespace, runners_minutes_used)
          pending_build.reload
          pending_build.create_queuing_entry!
        end

        it 'when in disaster recovery it ignores quota and returns anyway' do
          stub_feature_flags(ci_queueing_disaster_recovery_disable_quota: true)

          is_expected.to be_kind_of(Ci::Build)
        end

        it { is_expected.to be_nil }
      end

      context 'when limit set at global level' do
        before do
          stub_application_setting(shared_runners_minutes: 10)
        end

        context 'and usage is below the limit' do
          it_behaves_like 'returns a build', 9
        end

        context 'and usage is above the limit' do
          it_behaves_like 'does not return a build', 11

          context 'and project is public' do
            context 'and public projects cost factor is 0 (default)' do
              before do
                project.update!(visibility_level: Project::PUBLIC)
              end

              it_behaves_like 'returns a build', 11
            end

            context 'and public projects cost factor is > 0' do
              before do
                project.update!(visibility_level: Project::PUBLIC)
                shared_runner.update!(public_projects_minutes_cost_factor: 1.1)
              end

              it_behaves_like 'does not return a build', 11
            end
          end
        end

        context 'and extra shared runners minutes purchased' do
          before do
            project.namespace.update!(extra_shared_runners_minutes_limit: 10)
          end

          context 'and usage is below the combined limit' do
            it_behaves_like 'returns a build', 19
          end

          context 'and usage is above the combined limit' do
            it_behaves_like 'does not return a build', 21
          end
        end
      end

      context 'when limit set at namespace level' do
        before do
          project.namespace.update!(shared_runners_minutes_limit: 5)
        end

        context 'and limit set to unlimited' do
          before do
            project.namespace.update!(shared_runners_minutes_limit: 0)
          end

          it_behaves_like 'returns a build', 10
        end

        context 'and usage is below the limit' do
          it_behaves_like 'returns a build', 4
        end

        context 'and usage is above the limit' do
          it_behaves_like 'does not return a build', 6
        end

        context 'and extra shared runners minutes purchased' do
          before do
            project.namespace.update!(extra_shared_runners_minutes_limit: 5)
          end

          context 'and usage is below the combined limit' do
            it_behaves_like 'returns a build', 9
          end

          context 'and usage is above the combined limit' do
            it_behaves_like 'does not return a build', 11
          end
        end
      end

      context 'when limit set at global and namespace level' do
        context 'and namespace limit lower than global limit' do
          before do
            stub_application_setting(shared_runners_minutes: 10)
            project.namespace.update!(shared_runners_minutes_limit: 5)
          end

          it_behaves_like 'does not return a build', 6
        end

        context 'and namespace limit higher than global limit' do
          before do
            stub_application_setting(shared_runners_minutes: 5)
            project.namespace.update!(shared_runners_minutes_limit: 10)
          end

          it_behaves_like 'returns a build', 6
        end
      end

      context 'when group is subgroup' do
        let!(:root_ancestor) { create(:group) }
        let!(:group) { create(:group, parent: root_ancestor) }
        let!(:project) { create :project, shared_runners_enabled: true, group: group }

        context 'and usage below the limit on root namespace' do
          before do
            root_ancestor.update!(shared_runners_minutes_limit: 10)
          end

          it_behaves_like 'returns a build', 9
        end

        context 'and usage above the limit on root namespace' do
          before do
            # limit is ignored on subnamespace
            group.update_columns(shared_runners_minutes_limit: 20)

            root_ancestor.update!(shared_runners_minutes_limit: 10)
            set_ci_minutes_used(root_ancestor, 11)
          end

          it_behaves_like 'does not return a build', 11
        end
      end
    end

    context 'secrets' do
      let(:params) { { info: { features: { vault_secrets: true } } } }

      subject(:service) { described_class.new(shared_runner, nil) }

      before do
        stub_licensed_features(ci_secrets_management: true)
      end

      context 'when build has secrets defined' do
        before do
          pending_build.update!(
            secrets: {
              DATABASE_PASSWORD: {
                vault: {
                  engine: { name: 'kv-v2', path: 'kv-v2' },
                  path: 'production/db',
                  field: 'password'
                }
              }
            }
          )
        end

        context 'when there is Vault server provided' do
          it 'picks the build' do
            create(:ci_variable, project: project, key: 'VAULT_SERVER_URL', value: 'https://vault.example.com')

            build = service.execute(params).build

            aggregate_failures do
              expect(build).not_to be_nil
              expect(build).to be_running
            end
          end
        end

        context 'when there is no Vault server provided' do
          it 'does not pick the build and drops the build during the validation before assigning runner' do
            result = service.execute(params).build

            aggregate_failures do
              expect(result).to be_nil
              expect(pending_build.reload).to be_failed
              expect(pending_build.failure_reason).to eq('secrets_provider_not_found')
              expect(pending_build).to be_secrets_provider_not_found
            end
          end
        end

        context 'when build has id_tokens defined and there is secrets provider defined' do
          before do
            rsa_key = OpenSSL::PKey::RSA.generate(3072).to_s
            stub_application_setting(ci_jwt_signing_key: rsa_key)

            pending_build.metadata.update!(
              id_tokens: { 'TEST_ID_TOKEN' => { aud: 'https://client.test' } }
            )
            create(:ci_variable, project: project, key: 'VAULT_SERVER_URL', value: 'https://vault.example.com')
          end

          shared_examples 'it injects to JWT an expiry time eq' do |expiry_time|
            it do
              build = service.execute(params).build

              masked_id_token = build.variables['TEST_ID_TOKEN'].value
              id_token = JWT.decode(masked_id_token, nil, false).first
              expect(id_token['exp'] - id_token['iat']).to eq(expiry_time)
            end
          end

          it_behaves_like 'it injects to JWT an expiry time eq', 3699

          it 'computes the JWT tokens ONLY after the runner is assigned and build timeout metadata is set' do
            stubbed_build_metadata = instance_double(Ci::BuildMetadata)

            allow_next_found_instance_of(Ci::Build) do |pending_build|
              expect(pending_build).to receive(:run!).ordered.and_call_original
              expect(pending_build).to receive(:ensure_metadata).ordered.and_return(stubbed_build_metadata)
              expect(stubbed_build_metadata).to receive(:update_timeout_state).ordered
              expect(pending_build).to receive(:job_jwt_variables).ordered.and_call_original
            end

            service.execute(params).build
          end
        end
      end

      context 'when build has no secrets defined' do
        it 'picks the build' do
          build = service.execute(params).build

          aggregate_failures do
            expect(build).not_to be_nil
            expect(build).to be_running
          end
        end
      end

      context 'when secrets management feature is NOT available' do
        before do
          stub_licensed_features(ci_secrets_management: false)
        end

        it 'picks the build' do
          build = service.execute(params).build

          aggregate_failures do
            expect(build).not_to be_nil
            expect(build).to be_running
          end
        end
      end
    end
  end

  include_examples 'namespace minutes quota'

  describe 'ensure plan limitation', :saas do
    let_it_be(:premium_plan) { create(:premium_plan) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }

    let(:allowed_plan_ids) { [] }
    let(:plan_check_runner) { create(:ci_runner, :instance, allowed_plan_ids: allowed_plan_ids) }

    subject { described_class.new(plan_check_runner, nil).execute.build }

    context 'when namespace has no plan attached' do
      context 'runner does not define allowed plans' do
        it { is_expected.to be_kind_of(Ci::Build) }
      end

      context 'runner defines allowed plans' do
        let(:allowed_plan_ids) { [premium_plan.id] }

        it { is_expected.to be_nil }
      end
    end

    context 'when namespace has plan attached' do
      let(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }

      context 'runner does not define allowed plans' do
        it { is_expected.to be_kind_of(Ci::Build) }
      end

      context 'runner defines allowed plans' do
        let(:allowed_plan_ids) { [premium_plan.id] }

        it { is_expected.to be_kind_of(Ci::Build) }

        context 'allowed plans do not match namespace plan' do
          let(:allowed_plan_ids) { [ultimate_plan.id] }

          it { is_expected.to be_nil }

          context 'when in disaster recovery' do
            it 'ignores quota and returns anyway' do
              stub_feature_flags(ci_queuing_disaster_recovery_disable_allowed_plans: true)

              is_expected.to be_kind_of(Ci::Build)
            end
          end
        end
      end
    end
  end

  describe 'when group has IP address restrictions' do
    let(:group) { create(:group) }
    let(:project) { create :project, shared_runners_enabled: true, group: group }
    let(:group_ip_restriction) { true }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
      stub_licensed_features(group_ip_restriction: group_ip_restriction)

      create(:ip_restriction, group: group, range: range)
    end

    subject(:result) { described_class.new(shared_runner, nil).execute.build }

    shared_examples 'drops the build' do
      it 'does not pick the build', :aggregate_failures do
        expect(result).to be_nil
        expect(pending_build.reload).to be_failed
        expect(pending_build.failure_reason).to eq('ip_restriction_failure')
      end
    end

    shared_examples 'does not drop the build' do
      it 'picks the build', :aggregate_failures do
        expect(result).to be_kind_of(Ci::Build)
        expect(result).to be_running
      end
    end

    context 'address is within the range' do
      let(:range) { '192.168.0.0/24' }

      it_behaves_like 'does not drop the build'

      context 'when group is subgroup' do
        let(:sub_group) { create(:group, parent: group) }
        let(:project) { create :project, shared_runners_enabled: true, group: sub_group }

        it_behaves_like 'does not drop the build'
      end

      context 'when group_ip_restriction is not available' do
        let(:group_ip_restriction) { false }

        it_behaves_like 'does not drop the build'
      end
    end

    context 'address is outside the range' do
      let(:range) { '10.0.0.0/8' }

      it_behaves_like 'drops the build'

      context 'when group is subgroup' do
        let(:sub_group) { create(:group, parent: group) }
        let(:project) { create :project, shared_runners_enabled: true, group: sub_group }

        it_behaves_like 'drops the build'
      end

      context 'when group_ip_restriction is not available' do
        let(:group_ip_restriction) { false }

        it_behaves_like 'does not drop the build'
      end
    end
  end
end
