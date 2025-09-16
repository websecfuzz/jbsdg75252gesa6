# frozen_string_literal: true

RSpec.shared_examples 'deletes paired destination' do |model_var|
  let(:source_model) { send(model_var) }
  let(:paired) { send(:paired_model) }

  def stream_model?(destination_model)
    destination_model.is_a?(AuditEvents::Group::ExternalStreamingDestination) ||
      destination_model.is_a?(AuditEvents::Instance::ExternalStreamingDestination)
  end

  context 'when the feature flag is on' do
    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: true)

      if stream_model?(source_model)
        source_model.update_column(:legacy_destination_ref, paired.id)
        paired.update_column(:stream_destination_id, source_model.id)
      else
        source_model.update_column(:stream_destination_id, paired.id)
        paired.update_column(:legacy_destination_ref, source_model.id)
      end
    end

    it 'destroys both destinations' do
      expect { mutate }.to change { source_model.class.count }.by(-1).and change { paired.class.count }.by(-1)
    end
  end

  context 'when the feature flag is off' do
    before do
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)

      if stream_model?(source_model)
        source_model.update_column(:legacy_destination_ref, paired.id)
        paired.update_column(:stream_destination_id, source_model.id)
      else
        source_model.update_column(:stream_destination_id, paired.id)
        paired.update_column(:legacy_destination_ref, source_model.id)
      end
    end

    it 'does not destroy the paired destination' do
      expect { mutate }.to change { source_model.class.count }.by(-1).and not_change { paired.class.count }
    end
  end
end
