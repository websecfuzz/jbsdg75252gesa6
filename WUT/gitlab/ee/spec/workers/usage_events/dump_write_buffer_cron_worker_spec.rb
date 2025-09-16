# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsageEvents::DumpWriteBufferCronWorker, :clean_gitlab_redis_shared_state, feature_category: :value_stream_management do
  let_it_be(:organization) { create(:organization) }
  let(:job) { described_class.new }
  let(:perform) { job.perform }
  let_it_be(:personal_namespace) { create(:user_namespace) }

  let(:inserted_records) do
    UsageEvents::DumpWriteBufferCronWorker::MODELS.flat_map { |model| model.all.map(&:attributes) }
  end

  it 'does not insert anything' do
    perform

    expect(inserted_records).to be_empty
  end

  def add_to_buffer(attributes, model = Ai::CodeSuggestionEvent)
    data = { 'timestamp' => Time.current }.merge(attributes.stringify_keys)
    Ai::UsageEventWriteBuffer.add(model.name, data)
  end

  context 'when data is present' do
    before do
      add_to_buffer({ user_id: 3,
                    event: 'request_duo_chat_response',
                    organization_id: organization.id,
                    personal_namespace_id: personal_namespace.id },
        Ai::DuoChatEvent)
      add_to_buffer(user_id: 1, event: 'code_suggestion_shown_in_ide', organization_id: organization.id)
      add_to_buffer(user_id: 2, event: 'code_suggestion_shown_in_ide', organization_id: organization.id)
      add_to_buffer(
        user_id: 3,
        event: 'code_suggestion_shown_in_ide',
        organization_id: organization.id,
        payload: { language: 'ruby' })
      add_to_buffer({ user_id: 3,
                      event: 'troubleshoot_job',
                      organization_id: organization.id,
                      namespace_id: personal_namespace.id,
                      extras: { foo: 'bar' } },
        Ai::UsageEvent)
    end

    it 'inserts all rows' do
      status = perform

      expect(status).to eq({ status: :processed, inserted_rows: 5 })
      expect(inserted_records).to match([
        hash_including('user_id' => 3, 'event' => 'request_duo_chat_response'),
        hash_including('user_id' => 1, 'event' => 'code_suggestion_shown_in_ide'),
        hash_including('user_id' => 2, 'event' => 'code_suggestion_shown_in_ide'),
        hash_including('user_id' => 3, 'event' => 'code_suggestion_shown_in_ide',
          'payload' => { 'language' => 'ruby' }),
        hash_including('user_id' => 3, 'event' => 'troubleshoot_job')
      ])
    end

    context 'when looping twice' do
      it 'inserts all rows' do
        stub_const("#{described_class.name}::BATCH_SIZE", 2)

        expect(perform).to eq({ status: :processed, inserted_rows: 5 })
      end
    end

    context 'when time limit is up' do
      it 'returns over_time status' do
        stub_const("#{described_class.name}::BATCH_SIZE", 1)

        allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
          allow(limiter).to receive(:over_time?).and_return(false, false, true)
        end

        status = perform

        expect(status).to eq({ status: :over_time, inserted_rows: 2 })
        expect(inserted_records).to match([
          hash_including('user_id' => 3),
          hash_including('user_id' => 1)
        ])
      end
    end
  end

  context 'when data contains different sets of attributes' do
    before do
      add_to_buffer({ user_id: 1,
                      event: 'request_duo_chat_response',
                      organization_id: organization.id,
                      personal_namespace_id: personal_namespace.id },
        Ai::DuoChatEvent)
      add_to_buffer({ user_id: 2,
                      event: 'request_duo_chat_response',
                      organization_id: organization.id,
                      personal_namespace_id: personal_namespace.id },
        Ai::DuoChatEvent)
      add_to_buffer({ user_id: 3,
                      event: 'request_duo_chat_response',
                      organization_id: organization.id,
                      personal_namespace_id: personal_namespace.id,
                      namespace_path: '1/2/3/' },
        Ai::DuoChatEvent)
    end

    it 'inserts all rows by attribute groups' do
      expect(Ai::DuoChatEvent).to receive(:upsert_all).twice.and_call_original
      expect(perform).to eq({ status: :processed, inserted_rows: 3 })
    end
  end

  context 'when data contains obsolete attributes' do
    before do
      add_to_buffer({ user_id: 1,
                      event: 'request_duo_chat_response',
                      organization_id: organization.id,
                      personal_namespace_id: personal_namespace.id },
        Ai::DuoChatEvent)
      add_to_buffer({ user_id: 2,
                      event: 'request_duo_chat_response',
                      organization_id: organization.id,
                      personal_namespace_id: personal_namespace.id,
                      foo: 'bar' },
        Ai::DuoChatEvent)
    end

    it 'ignores extra attributes and inserts all rows' do
      expect(Ai::DuoChatEvent).to receive(:upsert_all).once.and_call_original
      expect(perform).to eq({ status: :processed, inserted_rows: 2 })
    end
  end
end
