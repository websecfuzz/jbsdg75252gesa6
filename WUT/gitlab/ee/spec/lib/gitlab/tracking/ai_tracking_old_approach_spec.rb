# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, **event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) do
      {
        user: current_user,
        branch_name: 'main',
        language: 'cobol',
        suggestion_size: 10,
        unique_tracking_id: "AB1"
      }
    end

    let(:event_name) { 'some_unknown_event' }

    let_it_be(:group) { create(:group, path: 'group') }
    let_it_be(:project) { create(:project, namespace: group, path: 'project') }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    shared_examples 'basic event tracking for' do |model_class|
      let(:base_event_hash) do
        {
          user: current_user,
          event: event_name,
          namespace_path: nil
        }.merge(event_payload_hash).with_indifferent_access
      end

      let(:expected_event_hash) { base_event_hash }

      context 'with clickhouse not available' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'stores event to postgres' do
          expect_next_instance_of(model_class, expected_event_hash) do |instance|
            expect(instance).to receive(:store_to_pg).and_call_original
          end

          track_event
        end
      end

      context 'when clickhouse is disabled for analytics' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'does not store new event to clickhouse' do
          expect_next_instance_of(model_class, expected_event_hash) do |instance|
            expect(instance).not_to receive(:store_to_clickhouse)
          end

          track_event
        end
      end

      context 'when event_name is nil' do
        let(:event_name) { nil }

        it 'does not track the event' do
          expect(model_class).not_to receive(:new)
          track_event
        end
      end

      it 'stores new event' do
        expect_next_instance_of(model_class, expected_event_hash) do |instance|
          expect(instance).to receive(:store_to_clickhouse).and_call_original
        end

        track_event
      end

      it 'creates an event with correct attributes' do
        expect(model_class).to receive(:new).with(expected_event_hash)
        track_event
      end

      it 'triggers last_duo_activity_on update' do
        expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

        track_event
      end
    end

    shared_examples 'namespace path handling for' do |model_class|
      context 'when building traversal path' do
        context 'when a project ID is provided' do
          let(:event_context) { super().merge(project_id: project.id) }
          let(:expected_event_hash) do
            base_event_hash.merge(namespace_path: project.reload.project_namespace.traversal_path)
          end

          it 'loads the project and includes the correct namespace path' do
            expect(model_class).to receive(:new).with(expected_event_hash).and_call_original
            track_event
          end
        end

        context 'when a project object is provided' do
          let(:event_context) { super().merge(project: project) }
          let(:expected_event_hash) do
            base_event_hash.merge(namespace_path: project.reload.project_namespace.traversal_path)
          end

          it 'uses the provided project and includes the correct namespace path' do
            expect(model_class).to receive(:new).with(expected_event_hash).and_call_original
            track_event
          end
        end

        context 'when a namespace_id is provided' do
          let(:event_context) { super().merge(namespace_id: project.namespace.id) }
          let(:expected_event_hash) do
            base_event_hash.merge(namespace_path: project.namespace.traversal_path)
          end

          it 'loads the namespace and includes the correct namespace path' do
            expect(model_class).to receive(:new).with(expected_event_hash).and_call_original
            track_event
          end
        end

        context 'when a namespace object is provided' do
          let(:event_context) { super().merge(namespace: project.namespace) }
          let(:expected_event_hash) do
            base_event_hash.merge(namespace_path: project.namespace.traversal_path)
          end

          it 'uses the provided namespace and includes the correct namespace path' do
            expect(model_class).to receive(:new).with(expected_event_hash).and_call_original
            track_event
          end
        end

        context 'when both project and namespace objects are provided' do
          let(:event_context) { super().merge(project: project, namespace: project.namespace) }
          let(:expected_event_hash) do
            base_event_hash.merge(namespace_path: project.reload.project_namespace.traversal_path)
          end

          it 'prefers project namespace path over namespace path' do
            expect(model_class).to receive(:new).with(expected_event_hash).and_call_original
            track_event
          end
        end
      end
    end

    context 'for code suggestion event' do
      let(:event_name) { 'code_suggestion_shown_in_ide' }
      let(:event_payload_hash) do
        {
          payload: {
            branch_name: 'main',
            language: 'cobol',
            suggestion_size: 10,
            unique_tracking_id: "AB1"
          }
        }
      end

      include_examples 'basic event tracking for', Ai::CodeSuggestionEvent
      include_examples 'namespace path handling for', Ai::CodeSuggestionEvent
    end

    context 'for chat event' do
      let(:event_name) { 'request_duo_chat_response' }
      let(:event_payload_hash) do
        {
          payload: {}
        }
      end

      include_examples 'basic event tracking for', Ai::DuoChatEvent
      include_examples 'namespace path handling for', Ai::DuoChatEvent
    end

    context 'for troubleshoot job event' do
      let(:event_name) { 'troubleshoot_job' }
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }
      let(:job) { create(:ci_build, pipeline: pipeline, project: project, user_id: current_user.id) }

      let(:event_context) { super().merge(job: job) }

      let(:base_event_hash) { super().merge(namespace_path: project.reload.project_namespace.traversal_path) }

      let(:event_payload_hash) do
        {
          job: job,
          user: current_user,
          payload: {}
        }
      end

      include_examples 'basic event tracking for', Ai::TroubleshootJobEvent
    end
  end

  describe '.track_user_activity' do
    let(:current_user) { create(:user) }

    it 'refreshes user metrics for last activity' do
      expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

      described_class.track_user_activity(current_user)
    end
  end
end
