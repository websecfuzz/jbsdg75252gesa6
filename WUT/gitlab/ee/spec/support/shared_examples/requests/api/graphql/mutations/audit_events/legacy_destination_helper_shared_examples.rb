# frozen_string_literal: true

RSpec.shared_examples 'creates a streaming destination' do |legacy_model_class, attributes_proc|
  before do
    stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)
  end

  let(:attributes) { instance_exec(&attributes_proc) }
  it 'creates a streaming destination with correct attributes' do
    expect { mutate }
    .to change { legacy_model_class.count }.by(1)

    legacy_destination = legacy_model_class.last
    stream_destination = legacy_destination.stream_destination

    aggregate_failures do
      expect(stream_destination.legacy_destination_ref).to eq(legacy_destination.id)
      expect(legacy_destination.stream_destination_id).to eq(stream_destination.id)

      attributes[:streaming].each do |key, value|
        expect(stream_destination.config[key]).to eq(value)
      end
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)
    end

    it 'does not create a streaming destination' do
      expect { mutate }
        .to not_change(AuditEvents::Group::ExternalStreamingDestination, :count)
        .and not_change(AuditEvents::Instance::ExternalStreamingDestination, :count)
    end
  end
end

RSpec.shared_examples 'updates a streaming destination' do |destination, attributes_proc|
  def get_secret_token(model, category)
    case category
    when :http then model.verification_token
    when :aws then model.secret_access_key
    when :gcp then model.private_key
    end
  end

  context 'when feature flag is enabled' do
    let(:attributes) { instance_exec(&attributes_proc) }

    let(:legacy_destination) { send(destination) }
    let(:paired_stream_destination) { send(:stream_destination) }

    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)

      legacy_destination.update!(stream_destination_id: paired_stream_destination.id)
      paired_stream_destination.update!(legacy_destination_ref: legacy_destination.id)
    end

    it 'updates the streaming destination with correct attributes' do
      mutate

      legacy_destination.reload
      paired_stream_destination.reload

      aggregate_failures do
        expect(paired_stream_destination.legacy_destination_ref).to eq(legacy_destination.id)
        expect(legacy_destination.stream_destination_id).to eq(paired_stream_destination.id)
        expect(get_secret_token(legacy_destination, paired_stream_destination.category.to_sym))
          .to eq(paired_stream_destination.secret_token)

        attributes[:streaming].each do |key, value|
          if key == "name"
            expect(paired_stream_destination.name).to eq(value)
          else
            expect(paired_stream_destination.config[key]).to eq(value)
          end
        end

        attributes[:legacy].each do |key, value|
          expect(legacy_destination[key]).to eq(value)
        end
      end
    end
  end

  context 'when feature flag is disabled' do
    let(:legacy_destination) { send(destination) }
    let(:paired_stream_destination) { send(:stream_destination) }

    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)
      legacy_destination.update!(stream_destination_id: paired_stream_destination.id)
      paired_stream_destination.update!(legacy_destination_ref: legacy_destination.id)
    end

    it 'does not update streaming destination' do
      original_config = paired_stream_destination.config.dup
      original_name = paired_stream_destination.name

      mutate

      paired_stream_destination.reload
      expect(paired_stream_destination.config).to eq(original_config)
      expect(paired_stream_destination.name).to eq(original_name)
    end
  end
end
