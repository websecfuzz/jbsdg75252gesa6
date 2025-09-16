# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house, :clean_gitlab_redis_shared_state do
    let_it_be(:group) { create(:group, path: 'group') }
    let_it_be(:organization) { create(:organization) }
    let_it_be(:current_user) { create(:user, organizations: [organization]) }
    let(:event_context) do
      { user: current_user }
    end

    let_it_be(:project) { create(:project, namespace: group, path: 'project') }

    subject(:track_event) { described_class.track_event(event_name, **event_context) }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    describe 'guessing namespace ID' do
      let(:event_context) { { user: current_user } }
      let(:event_name) { 'request_duo_chat_response' }
      let(:expected_event_hash) do
        { user: current_user, event: event_name, extras: {} }
      end

      context 'with project ID provided' do
        let(:event_context) { super().merge(project_id: project.id, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'includes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with project object is provided' do
        let(:event_context) { super().merge(project: project, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'includes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace ID provided' do
        let(:event_context) { super().merge(namespace_id: group.id) }

        let(:expected_event_hash) do
          super().merge(namespace_id: group.id)
        end

        it 'includes namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace object is provided' do
        let(:event_context) { super().merge(namespace: group, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: group.id)
        end

        it 'includes namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace ID and project ID is provided' do
        let(:event_context) { super().merge(namespace_id: group.id, project_id: project.id) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'takes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end
    end

    %w[code_suggestion_shown_in_ide code_suggestion_accepted_in_ide code_suggestion_rejected_in_ide].each do |e|
      context "for `#{e}` event" do
        let(:event_name) { e }
        let(:event_context) { extras.merge(user: current_user) }
        let(:extras) do
          {
            unique_tracking_id: "AB1",
            suggestion_size: 10,
            language: 'cobol',
            branch_name: 'main'
          }
        end

        let(:expected_pg_attributes) do
          {
            user_id: current_user.id,
            event: event_name,
            extras: extras
          }
        end

        let(:expected_ch_attributes) do
          {
            user_id: current_user.id,
            event: Ai::UsageEvent.events[event_name],
            extras: extras.to_json
          }
        end

        it_behaves_like 'standard ai usage event tracking'
      end
    end

    context 'for `request_duo_chat_response` event' do
      let(:event_name) { 'request_duo_chat_response' }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `troubleshoot_job` event' do
      let(:event_name) { 'troubleshoot_job' }
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }
      let(:job) { create(:ci_build, pipeline: pipeline, project: project, user_id: current_user.id) }

      let(:event_context) { { job: job, user: current_user } }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: project.project_namespace_id,
          extras: {
            job_id: job.id,
            project_id: project.id,
            pipeline_id: pipeline.id,
            merge_request_id: merge_request.id
          }
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: project.project_namespace.reload.traversal_path,
          extras: {
            job_id: job.id,
            project_id: project.id,
            pipeline_id: pipeline.id,
            merge_request_id: merge_request.id
          }.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end
  end
end
