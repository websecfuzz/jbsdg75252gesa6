# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NewEpicWorker, feature_category: :portfolio_management do
  describe '#perform' do
    let(:worker) { described_class.new }

    context 'when an epic not found' do
      it 'does not call Services' do
        expect(NotificationService).not_to receive(:new)

        worker.perform(non_existing_record_id, create(:user).id)
      end
    end

    context 'when a user not found' do
      it 'does not call Services' do
        expect(NotificationService).not_to receive(:new)

        worker.perform(create(:epic).id, non_existing_record_id)
      end
    end
  end
end
