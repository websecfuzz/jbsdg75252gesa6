# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::DuoCoreTodoNotificationWorker, feature_category: :acquisition do
  describe '#perform' do
    let_it_be(:users) { create_list(:user, 3) }
    let(:duo_enabled) { true }

    subject(:perform) { described_class.new.perform }

    before do
      allow(::Ai::Setting).to receive(:duo_core_features_enabled?).and_return(duo_enabled)
    end

    context 'when duo core features are enabled' do
      it 'creates todos for eligible users' do
        expect { perform }.to change { Todo.count }.by(3)

        expect(Todo.all.pluck(:user_id)).to match_array(users.map(&:id))
      end

      context 'when duo core features are disabled during processing' do
        before do
          # First check returns true, second check returns false
          allow(::Ai::Setting).to receive(:duo_core_features_enabled?).and_return(true, false)
        end

        it 'stops processing batches' do
          expect { perform }.not_to change { Todo.count }
        end
      end
    end

    context 'when duo core features are disabled' do
      let(:duo_enabled) { false }

      it 'does not create todos' do
        expect { perform }.not_to change { Todo.count }
      end
    end
  end

  it_behaves_like 'an idempotent worker'
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed
end
