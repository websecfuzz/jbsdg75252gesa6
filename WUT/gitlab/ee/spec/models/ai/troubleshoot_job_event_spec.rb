# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::TroubleshootJobEvent, feature_category: :duo_chat do
  subject(:event) { described_class.new(attributes) }

  let_it_be(:user) { create(:user) }
  let_it_be(:job) { create(:ci_build) }
  let_it_be(:project) { create(:project, :private, developers: user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }

  let(:attributes) { { event: 'troubleshoot_job', user: user, job: job } }

  it { is_expected.to belong_to(:job) }
  it { is_expected.to belong_to(:project) }

  it_behaves_like 'common ai_usage_event'

  describe 'validations' do
    it { is_expected.to validate_presence_of(:job_id) }
  end

  describe '.payload_attributes' do
    it 'has list of payload attributes' do
      expect(described_class.payload_attributes).to match_array(%w[pipeline_id merge_request_id])
    end
  end

  describe 'populating sharding key project_id' do
    let(:event) { described_class.new(job: job) }

    it { is_expected.to populate_sharding_key(:project_id).with(job.project_id) }
  end

  describe '#store_to_pg', :freeze_time do
    context 'when the model is invalid' do
      let(:attributes) { {} }

      it 'does not add anything to write buffer' do
        expect(Ai::UsageEventWriteBuffer).not_to receive(:add)

        event.store_to_pg
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(
          user: user,
          timestamp: 1.day.ago,
          payload: {
            pipeline_id: 2,
            merge_request_id: 3
          }
        )
      end

      it 'adds model attributes to write buffer' do
        expect(Ai::UsageEventWriteBuffer).to receive(:add)
          .with(described_class.name, {
            event: 'troubleshoot_job',
            timestamp: 1.day.ago,
            user_id: user.id,
            project_id: job.project_id,
            job_id: job.id,
            payload: {
              pipeline_id: 2,
              merge_request_id: 3
            }
          }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let_it_be(:job) { create(:ci_build, pipeline: pipeline) }

    context 'with specified payload values' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          timestamp: 1.day.ago,
          project_id: job.project.id,
          payload: {
            pipeline_id: 2,
            merge_request_id: 202
          }
        }
      end

      it 'returns serialized attributes hash with provided payload values' do
        expect(event.to_clickhouse_csv_row).to include(
          user_id: user.id,
          pipeline_id: 2,
          merge_request_id: 202,
          timestamp: 1.day.ago.to_f,
          job_id: job.id
        )
      end
    end

    context 'with values derived from job' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          timestamp: 1.day.ago,
          project_id: project.id,
          payload: {}
        }
      end

      it 'returns serialized attributes hash with values derived from job' do
        event.validate

        expect(event.to_clickhouse_csv_row).to include(
          user_id: user.id,
          pipeline_id: pipeline.id,
          merge_request_id: pipeline.merge_request_id,
          timestamp: 1.day.ago.to_f,
          job_id: job.id
        )
      end
    end

    context 'with nil payload values' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          timestamp: 1.day.ago,
          project_id: job.project.id,
          payload: { pipeline_id: nil, merge_request_id: nil }
        }
      end

      it 'includes nil values in the serialized hash' do
        expect(event.to_clickhouse_csv_row).to include(
          pipeline_id: nil,
          merge_request_id: nil
        )
      end
    end
  end

  describe '#fill_payload' do
    let_it_be(:job) { create(:ci_build, pipeline: pipeline) }

    context 'when payload is empty' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          payload: {}
        }
      end

      it 'fills payload with job attributes during validation' do
        expect { event.validate }.to change { event.payload }
          .from({})
          .to(include(
            'pipeline_id' => pipeline.id,
            'merge_request_id' => pipeline.merge_request_id
          ))
      end
    end

    context 'when payload already has values' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          payload: {
            'pipeline_id' => 10,
            'merge_request_id' => 20
          }
        }
      end

      it 'does not overwrite existing values during validation' do
        event.validate
        expect(event.payload).to include(
          'pipeline_id' => 10,
          'merge_request_id' => 20
        )
      end
    end

    context 'when job has no merge_request' do
      let(:attributes) do
        {
          event: 'troubleshoot_job',
          user: user,
          job: job,
          payload: {
            'pipeline_id' => pipeline.id,
            'merge_request_id' => nil
          }
        }
      end

      it 'sets pipeline_id and merge request based on pipeline data' do
        event.validate
        expect(event.payload).to include('pipeline_id' => pipeline.id)
        expect(event.payload).to include('merge_request_id' => pipeline.merge_request_id)
      end
    end
  end
end
