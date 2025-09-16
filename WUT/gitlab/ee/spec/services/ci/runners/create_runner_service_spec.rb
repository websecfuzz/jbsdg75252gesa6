# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::CreateRunnerService, '#execute', feature_category: :runner do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group_owner) { create(:user) }
  let_it_be(:group) { create(:group, owners: group_owner) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:runner) { execute.payload[:runner] }
  let(:expected_audit_kwargs) do
    {
      name: 'ci_runner_created',
      message: 'Created %{runner_type} CI runner'
    }
  end

  let(:service) { described_class.new(user: current_user, params: params) }

  subject(:execute) { service.execute }

  RSpec::Matchers.define :last_ci_runner do
    match { |runner| runner == ::Ci::Runner.last }
  end

  shared_examples 'runner creation transaction behavior' do
    context 'when runner save fails' do
      before do
        allow_next_instance_of(Ci::Runner) do |r|
          r.errors.add(:base, "Runner validation failed")
          allow(r).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(r))
        end
      end

      it 'returns error response with runner validation messages' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:save_error)
        expect(response.message).to include("Runner validation failed")
      end

      it 'does not create any records' do
        expect { execute }
          .to not_change { Ci::Runner.count }
          .and not_change { Ci::HostedRunner.count }
      end
    end

    context 'when hosted runner creation fails' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        params[:hosted_runner] = true

        allow(service).to receive(:create_hosted_runner!).and_raise(
          ActiveRecord::RecordInvalid.new(Ci::HostedRunner.new).tap do |e|
            e.record.errors.add(:base, "Hosted runner validation failed")
          end
        )
      end

      it 'returns error response with hosted runner validation messages' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:save_error)
        expect(response.message).to include("Hosted runner validation failed")
      end

      it 'does not create any records' do
        expect { execute }
          .to not_change { Ci::Runner.count }
          .and not_change { Ci::HostedRunner.count }
      end
    end
  end

  shared_examples 'a service logging a runner audit event' do
    it 'returns newly-created runner' do
      expect_next_instance_of(
        ::AuditEvents::RunnerAuditEventService,
        last_ci_runner, current_user, expected_token_scope, **expected_audit_kwargs
      ) do |service|
        expect(service).to receive(:track_event).once.and_call_original
      end

      expect(execute).to be_success
      expect(runner).to eq(::Ci::Runner.last)
    end
  end

  shared_examples 'hosted runner created' do
    it 'creates a hosted runner record' do
      expect { subject }.to change { ::Ci::HostedRunner.count }.by(1)
    end

    it 'associates the hosted runner with the created runner' do
      response = subject
      runner = response.payload[:runner]

      expect(Ci::HostedRunner.last.runner_id).to eq(runner.id)
    end
  end

  shared_examples 'hosted runner not created' do
    it 'does not create a hosted runner record' do
      expect { subject }.not_to change { ::Ci::HostedRunner.count }
    end
  end

  context 'with :runner_type param set to instance_type' do
    let(:current_user) { admin }
    let(:params) { { runner_type: 'instance_type' } }
    let(:expected_token_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    it 'runner payload is nil' do
      expect(runner).to be_nil
    end

    it { is_expected.to be_error }

    context 'when admin mode is enabled', :enable_admin_mode do
      it_behaves_like 'a service logging a runner audit event'
      it_behaves_like 'runner creation transaction behavior'

      context 'on a dedicated instance' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        end

        context 'with hosted_runner param set to true' do
          before do
            params[:hosted_runner] = true
          end

          it_behaves_like 'hosted runner created'
        end

        context 'with hosted_runner param set to false' do
          before do
            params[:hosted_runner] = false
          end

          it_behaves_like 'hosted runner not created'
        end
      end

      context 'when not on a dedicated instance' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
          params[:hosted_runner] = true
        end

        it_behaves_like 'hosted runner not created'
      end
    end
  end

  context 'with :runner_type param set to group_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'group_type', scope: group } }
    let(:expected_token_scope) { group }

    it_behaves_like 'a service logging a runner audit event'
    it_behaves_like 'hosted runner not created'

    context 'with hosted_runner param set to true' do
      before do
        params[:hosted_runner] = true
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it_behaves_like 'hosted runner not created'
    end
  end

  context 'with :runner_type param set to project_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'project_type', scope: project } }
    let(:expected_token_scope) { project }

    it_behaves_like 'a service logging a runner audit event'
    it_behaves_like 'hosted runner not created'

    context 'with hosted_runner param set to true' do
      before do
        params[:hosted_runner] = true
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
      end

      it_behaves_like 'hosted runner not created'
    end
  end
end
