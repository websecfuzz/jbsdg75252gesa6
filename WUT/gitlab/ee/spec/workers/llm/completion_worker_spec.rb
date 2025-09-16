# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::CompletionWorker, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:thread) { create(:ai_conversation_thread, user: user) }

  let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
  let(:options) { { 'key' => 'value' } }
  let(:ai_action_name) { :summarize_comments }

  let(:prompt_message) do
    build(:ai_message,
      user: user, resource: resource, ai_action: ai_action_name, request_id: 'uuid', user_agent: user_agent,
      thread: thread
    )
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    subject { worker.perform(described_class.serialize_message(prompt_message), options) }

    let(:worker) { described_class.new }
    let(:session) { ActionController::TestSession.new }

    def expect_completion_service_call
      expect_next_instance_of(
        Llm::Internal::CompletionService,
        an_object_having_attributes(
          user: user,
          resource: resource,
          request_id: 'uuid',
          ai_action: ai_action_name,
          thread: thread
        ),
        options
      ) do |instance|
        expect(instance).to receive(:execute)
      end
    end

    it 'calls Llm::Internal::CompletionService and tracks event' do
      expect_completion_service_call
      expect(worker).to receive(:log_extra_metadata_on_done).with(:ai_action, ai_action_name)

      subject

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'perform_completion_worker',
        label: ai_action_name.to_s,
        property: 'uuid',
        user: user,
        client: 'web'
      )
    end

    it 'tracks user AI feature utilization' do
      expect_completion_service_call
      expect(worker).to receive(:log_extra_metadata_on_done).with(:ai_action, ai_action_name)
      expect(Gitlab::Tracking::AiTracking).to receive(:track_user_activity).with(user)

      subject
    end

    context 'when warden.user.user.key is nil' do
      it 'simulates it' do
        expect_completion_service_call
        expect(worker).to receive(:log_extra_metadata_on_done).with(:ai_action, ai_action_name)

        Gitlab::Session.with_session(session) do
          subject

          expect(Gitlab::Session.current['warden.user.user.key']).to match_array([[user.id], instance_of(String)])
        end
      end

      context 'when sessionless' do
        it 'does nothing' do
          expect_completion_service_call
          expect(worker).to receive(:log_extra_metadata_on_done).with(:ai_action, ai_action_name)

          subject

          expect(Gitlab::Session.current).to eq(nil)
        end
      end
    end
  end

  describe '.perform_for' do
    let(:ip_address) { '1.1.1.1' }

    before do
      allow(::Gitlab::IpAddressState).to receive(:current).and_return(ip_address)
    end

    it 'sets set_ip_address to true' do
      described_class.perform_for(prompt_message, options)

      job = described_class.jobs.first

      expect(job).to include(
        'ip_address_state' => ip_address,
        'args' => [
          hash_including("ai_action" => ai_action_name.to_s),
          options
        ]
      )
    end

    it 'sets set_session_id' do
      allow(::Gitlab::Session).to receive(:session_id_for_worker).and_return('abc')

      described_class.perform_for(prompt_message, options)

      job = described_class.jobs.first

      expect(job).to include(
        'ip_address_state' => ip_address,
        'set_session_id' => 'abc',
        'args' => [
          hash_including("ai_action" => ai_action_name.to_s),
          options
        ]
      )
    end
  end

  describe '.resource' do
    subject { described_class.resource(message_hash) }

    let(:message_hash) do
      {
        'context' => {
          'resource' => resource.to_gid.to_s
        }
      }
    end

    it 'returns the resource' do
      expect(subject).to eq(resource)
    end

    context 'when the resource is a commit' do
      let_it_be(:project) { create(:project, :public, :repository) }
      let_it_be(:commit)  { project.commit }

      let(:message_hash) do
        {
          'context' => {
            'resource' => commit.to_gid.to_s,
            'project' => project.to_gid.to_s
          }
        }
      end

      it 'returns the project commit' do
        expect(subject).to eq(commit)
      end
    end
  end
end
