# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessages::UpdateService, feature_category: :acquisition do
  describe '#execute' do
    let_it_be(:targeted_message, reload: true) { create(:targeted_message) }

    subject(:execute) { described_class.new(targeted_message, targeted_message_params).execute }

    context 'when targeted message param is valid' do
      let_it_be(:targeted_namespace_ids) { create_list(:namespace, 2).map(&:id) }
      let(:invalid_namespace_ids) { [] }
      let(:targeted_message_params) { targeted_message.attributes.merge(namespace_ids_csv: csv_file) }
      let(:csv_content) { (targeted_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
      let(:temp_file) do
        temp_file = Tempfile.new(%w[namespace_ids csv])
        temp_file.write(csv_content)
        temp_file.rewind

        temp_file
      end

      let(:csv_file) { fixture_file_upload(temp_file.path, 'text/csv') }

      after do
        temp_file.unlink
      end

      it 'returns a success service response' do
        expect(execute).to be_success
        expect(execute.payload).to be_a(Notifications::TargetedMessage)
      end

      context 'with invalid namespace ids' do
        let(:invalid_namespace_ids) { [non_existing_record_id] }

        it 'returns a error service response warning about invalid namespace ids' do
          partial_success_message = "Targeted message was successfully updated. But the following namespace ids " \
            "were invalid and have been ignored: #{invalid_namespace_ids.join(', ')}"

          expect(execute).to be_error
          expect(execute.message).to eq(partial_success_message)
          expect(execute.reason).to eq(described_class::FOUND_INVALID_NAMESPACES)
        end
      end

      context 'with new set of targeted message namespace ids' do
        it 'replaces targeted namespaces with new set' do
          execute

          expect(targeted_message.reload.targeted_message_namespaces.map(&:namespace_id))
            .to match_array(targeted_namespace_ids)
        end
      end
    end

    context 'when targeted message is invalid' do
      let(:targeted_message_params) { { target_type: '', namespace_ids_csv: 'stubbed file' } }

      it 'returns an error service response' do
        expect(execute).to be_error
        expect(execute.payload.errors.full_messages).to include('Target type can\'t be blank')
      end

      it 'returns a error service response with the csv parsing error added to targeted message' do
        allow_next_instance_of(Notifications::TargetedMessages::NamespaceIdsBuilder) do |builder|
          allow(builder).to receive(:build).and_return({
            valid_namespace_ids: [],
            invalid_namespace_ids: [],
            success: false,
            message: 'CSV parse error'
          })
        end

        expect(execute).to be_error
        expect(execute.payload.errors.full_messages).to include("CSV parse error")
      end
    end
  end
end
