# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::Progress, feature_category: :onboarding do
  let(:namespace) { create(:namespace) }
  let(:action) { :merge_request_created }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    describe 'namespace_is_root_namespace' do
      subject(:onboarding_progress) { build(:onboarding_progress, namespace: namespace) }

      context 'when associated namespace is root' do
        it { is_expected.to be_valid }
      end

      context 'when associated namespace is not root' do
        let(:namespace) { build(:group, :nested) }

        it 'is invalid' do
          expect(onboarding_progress).to be_invalid
          expect(onboarding_progress.errors[:namespace]).to include('must be a root namespace')
        end
      end
    end
  end

  describe '.onboard' do
    subject(:onboard) { described_class.onboard(namespace) }

    it 'adds a record for the namespace' do
      expect { onboard }.to change { described_class.count }.from(0).to(1)
    end

    context 'when not given a namespace' do
      let(:namespace) { nil }

      it 'does not add a record for the namespace' do
        expect { onboard }.not_to change { described_class.count }.from(0)
      end
    end

    context 'when not given a root namespace' do
      let(:namespace) { create(:group, parent: build(:group)) }

      it 'does not add a record for the namespace' do
        expect { onboard }.not_to change { described_class.count }.from(0)
      end
    end
  end

  describe '.onboarding?' do
    subject(:onboarding?) { described_class.onboarding?(namespace) }

    context 'when onboarded' do
      before do
        described_class.onboard(namespace)
      end

      it { is_expected.to eq true }

      context 'when onboarding has ended' do
        before do
          described_class.last.update!(ended_at: Time.current)
        end

        it { is_expected.to eq false }
      end
    end

    context 'when not onboarding' do
      it { is_expected.to eq false }
    end
  end

  describe '.register' do
    context 'for a single action' do
      subject(:register_action) { described_class.register(namespace, action) }

      context 'when the namespace was onboarded' do
        before do
          described_class.onboard(namespace)
        end

        it 'registers the action for the namespace' do
          expect { register_action }.to change { described_class.completed?(namespace, action) }.from(false).to(true)
        end

        it 'does not override timestamp', :aggregate_failures do
          expect(described_class.find_by_namespace_id(namespace.id).merge_request_created_at).to be_nil
          register_action
          expect(described_class.find_by_namespace_id(namespace.id).merge_request_created_at).not_to be_nil
          expect do
            described_class.register(namespace, action)
          end.not_to change { described_class.find_by_namespace_id(namespace.id).merge_request_created_at }
        end

        context 'when the action does not exist' do
          let(:action) { :foo }

          it 'does not register the action for the namespace' do
            expect { register_action }.not_to change { described_class.completed?(namespace, action) }.from(false)
          end
        end
      end

      context 'when the namespace was not onboarded' do
        it 'does not register the action for the namespace' do
          expect { register_action }.not_to change { described_class.completed?(namespace, action) }.from(false)
        end
      end
    end

    context 'for multiple actions' do
      let(:action1) { :secure_dast_run }
      let(:action2) { :secure_dependency_scanning_run }
      let(:actions) { [action1, action2] }

      subject(:register_action) { described_class.register(namespace, actions) }

      context 'when the namespace was onboarded' do
        before do
          described_class.onboard(namespace)
        end

        it 'registers the actions for the namespace' do
          expect { register_action }.to change {
            [described_class.completed?(namespace, action1), described_class.completed?(namespace, action2)]
          }.from([false, false]).to([true, true])
        end

        it 'does not override timestamp', :aggregate_failures do
          described_class.register(namespace, [action1])
          expect(described_class.find_by_namespace_id(namespace.id).secure_dast_run_at).not_to be_nil
          expect(described_class.find_by_namespace_id(namespace.id).secure_dependency_scanning_run_at).to be_nil

          expect { described_class.register(namespace, [action1, action2]) }.not_to change {
            described_class.find_by_namespace_id(namespace.id).secure_dast_run_at
          }
          expect(described_class.find_by_namespace_id(namespace.id).secure_dependency_scanning_run_at).not_to be_nil
        end

        context 'when one of the actions does not exist' do
          let(:action2) { :foo }

          it 'does not register any action for the namespace' do
            expect { register_action }.not_to change {
              [described_class.completed?(namespace, action1), described_class.completed?(namespace, action2)]
            }.from([false, false])
          end
        end
      end

      context 'when the namespace was not onboarded' do
        it 'does not register the action for the namespace' do
          expect { register_action }.not_to change { described_class.completed?(namespace, action1) }.from(false)
          expect do
            described_class.register(namespace, action)
          end.not_to change { described_class.completed?(namespace, action2) }.from(false)
        end
      end
    end
  end

  describe '.completed?' do
    subject { described_class.completed?(namespace, action) }

    context 'when the namespace has not yet been onboarded' do
      it { is_expected.to eq(false) }
    end

    context 'when the namespace has been onboarded but not registered the action yet' do
      before do
        described_class.onboard(namespace)
      end

      it { is_expected.to eq(false) }

      context 'when the action has been registered' do
        before do
          described_class.register(namespace, action)
        end

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '.column_name' do
    subject { described_class.column_name(action) }

    it { is_expected.to eq(:merge_request_created_at) }
  end
end
