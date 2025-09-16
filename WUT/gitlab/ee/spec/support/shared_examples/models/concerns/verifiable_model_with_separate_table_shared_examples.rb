# frozen_string_literal: true

# 2 Required let variables that should be valid, unpersisted instances of the same
# model class. Or valid, persisted instances of the same model class in a not-yet
# loaded let variable (so we can trigger creation):
#
# - verifiable_model_record: should be such that it will be included in the scope
#                            available_verifiables
# - unverifiable_model_record: should be such that it will not be included in
#                              the scope available_verifiables

RSpec.shared_examples 'a verifiable model with a separate table for verification state' do
  include EE::GeoHelpers

  before do
    stub_feature_flags(geo_object_storage_verification: false)
  end

  context 'on a primary node' do
    let(:primary) { create(:geo_node, :primary) }
    let(:secondary) { create(:geo_node, :secondary) }
    let(:verifiable_model_class) { verifiable_model_record.class }

    before do
      stub_current_geo_node(primary)
    end

    describe '.with_verification_state' do
      it 'returns records with given scope' do
        expect(verifiable_model_class.with_verification_state(:verification_succeeded).size).to eq(0)

        verifiable_model_record.save!
        verifiable_model_record.verification_failed_with_message!('Test')

        expect(
          verifiable_model_class.with_verification_state(:verification_failed).first
        ).to eq verifiable_model_record
      end
    end

    describe '.checksummed' do
      it 'returns records with given scope' do
        expect(verifiable_model_class.checksummed.size).to eq(0)

        verifiable_model_record.save!
        verifiable_model_record.verification_started!
        verifiable_model_record.verification_succeeded_with_checksum!('checksum', Time.now)

        expect(verifiable_model_class.checksummed.first).to eq verifiable_model_record
      end
    end

    describe '.not_checksummed' do
      it 'returns records with given scope' do
        verifiable_model_record.verification_started!
        verifiable_model_record.verification_failed_with_message!('checksum error')

        expect(verifiable_model_class.not_checksummed.first).to eq verifiable_model_record

        verifiable_model_record.verification_started!
        verifiable_model_record.verification_succeeded_with_checksum!('checksum', Time.now)

        expect(verifiable_model_class.not_checksummed.size).to eq(0)
      end
    end

    describe '#save_verification_details' do
      let(:verification_state_table_class) { verifiable_model_class.verification_state_table_class }
      let(:replicator_class) { verifiable_model_class.replicator_class }

      shared_examples 'does not create verification details' do
        it 'does not create verification details' do
          expect { verifiable_model_record.save! }.not_to change { verification_state_table_class.count }
        end
      end

      shared_examples 'creates verification details' do
        it 'creates verification details' do
          expect { verifiable_model_record.save! }.to change { verification_state_table_class.count }.by(1)
        end
      end

      context 'when site is not primary' do
        before do
          stub_current_geo_node(secondary)
        end

        it_behaves_like 'does not create verification details'
      end

      context 'when verification is not enabled' do
        before do
          stub_dummy_verification_feature_flag(replicator_class: replicator_class.name, enabled: false)
        end

        it_behaves_like 'does not create verification details'
      end

      context 'when model record is not part of verifiables scope' do
        before do
          next unless unverifiable_model_record.nil?

          skip "Skipping because all #{replicator_class.replicable_title_plural} are records that can be checksummed"
        end

        it 'does not create verification details' do
          expect { unverifiable_model_record.save! }.not_to change { verification_state_table_class.count }
        end
      end

      context 'when all conditions are met for saving verification' do
        before do
          stub_current_geo_node(primary)
          stub_dummy_verification_feature_flag(replicator_class: replicator_class.name)
        end

        it_behaves_like 'creates verification details'
      end
    end

    describe '#verification_pending_batch' do
      it 'logs the verification state transition' do
        verifiable_model_record.save!

        expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
          message: 'Batch verification state transition',
          table: verifiable_model_class.verification_state_table_name,
          "#{verifiable_model_class.verification_state_model_key}": verifiable_model_record.id.to_s,
          count: 1,
          from: 'verification_pending',
          to: 'verification_started',
          method: 'verification_pending_batch'
        ))

        verifiable_model_class.verification_pending_batch(batch_size: 4)
      end
    end

    describe '#verification_failed_batch' do
      it 'logs the verification state transition' do
        verifiable_model_record.verification_started
        verifiable_model_record.verification_failed_with_message!('checksum error')
        verifiable_model_record.update!(verification_retry_at: nil) # let it retry immediately

        expect(Gitlab::Geo::Logger).to receive(:debug).with(hash_including(
          message: 'Batch verification state transition',
          table: verifiable_model_class.verification_state_table_name,
          "#{verifiable_model_class.verification_state_model_key}": verifiable_model_record.id.to_s,
          count: 1,
          from: 'verification_failed',
          to: 'verification_started',
          method: 'verification_failed_batch'
        ))

        verifiable_model_class.verification_failed_batch(batch_size: 4)
      end
    end

    describe '#fail_verification_timeouts' do
      it 'logs the verification state transition' do
        verifiable_model_record.save! # trigger after commit create callback already (sets verification pending)
        verifiable_model_record.verification_started
        verifiable_model_record.verification_started_at = 1.day.ago
        verifiable_model_record.save!

        expect(Gitlab::Geo::Logger).to receive(:warn).with(
          hash_including(
            class: verifiable_model_class.verification_state_table_class.name,
            from: 'verification_started',
            gitlab_host: "localhost",
            id: Integer,
            message: 'Verification state transition',
            model_record_id: anything,
            result: true,
            to: 'verification_failed'
          )
        )

        verifiable_model_class.fail_verification_timeouts
      end
    end
  end
end
