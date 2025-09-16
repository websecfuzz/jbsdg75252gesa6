# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::SaasRolloutEventWorker, feature_category: :global_search do
  let(:worker) { described_class.new }
  let(:event) { Search::Zoekt::SaasRolloutEvent.new(data: {}) }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  context 'when not on .com' do
    it 'does nothing' do
      expect { consume_event(subscriber: described_class, event: event) }.not_to change {
        Search::Zoekt::EnabledNamespace.count
      }
    end
  end

  context 'when on .com', :saas do
    it_behaves_like 'an idempotent worker' do
      let_it_be(:namespace1) { create(:group) }
      let_it_be(:namespace2) { create(:group) }
      let_it_be(:namespace3) { create(:group) }
      let_it_be(:namespace4) { create(:group) }

      let_it_be(:subscription1) { create(:gitlab_subscription, namespace: namespace1) }
      let_it_be(:subscription2) { create(:gitlab_subscription, namespace: namespace2) }
      let_it_be(:expired_subscription) { create(:gitlab_subscription, namespace: namespace3, end_date: 2.days.ago) }
      let_it_be(:free_subscription) { create(:gitlab_subscription, :free, namespace: namespace4) }

      it 'creates enabled namespaces for paid subscriptions' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { Search::Zoekt::EnabledNamespace.count }.by(2)

        expect(Search::Zoekt::EnabledNamespace.pluck(:root_namespace_id))
          .to contain_exactly(namespace1.id, namespace2.id)
      end

      context 'when some namespaces are already enabled' do
        before do
          create(:zoekt_enabled_namespace, namespace: namespace1)
        end

        it 'only creates enabled namespaces for paid subscriptions that are not already enabled' do
          expect { consume_event(subscriber: described_class, event: event) }
            .to change { Search::Zoekt::EnabledNamespace.count }.by(1)

          expect(Search::Zoekt::EnabledNamespace.where(root_namespace_id: namespace2.id)).to exist
        end
      end

      context 'when number of namespaces exceeds batch size' do
        before do
          stub_const("#{described_class}::BUFFER_SIZE", 1)
          stub_const("#{described_class}::BATCH_SIZE", 1)
        end

        it 'processes only up to the batch size and schedules another event' do
          expect(Gitlab::EventStore).to receive(:publish).with(
            an_object_having_attributes(class: Search::Zoekt::SaasRolloutEvent, data: {})
          )

          expect { consume_event(subscriber: described_class, event: event) }
            .to change { Search::Zoekt::EnabledNamespace.count }.by(1)
        end
      end
    end
  end
end
