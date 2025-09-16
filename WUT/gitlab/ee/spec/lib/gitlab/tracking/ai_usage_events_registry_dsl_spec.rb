# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiUsageEventsRegistryDsl, feature_category: :value_stream_management do
  subject(:registry_module) do
    Class.new.tap do |module_class|
      module_class.extend(Gitlab::Tracking::AiUsageEventsRegistryDsl)
    end
  end

  context 'without events registered' do
    it 'returns empty events hash' do
      expect(registry_module.registered_events).to eq({})
    end

    it 'returns empty transformations array' do
      expect(registry_module.registered_transformations(:some_event)).to eq([])
    end
  end

  context 'with events registered' do
    it 'fails when event does not have internal events definition' do
      expect do
        registry_module.register do
          events(unknown_event: 1)
        end
      end.to raise_error("Event `unknown_event` is not defined in InternalEvents")
    end

    context 'with InternalEvents definition in place' do
      before do
        allow(Gitlab::Tracking::EventDefinition).to receive(:internal_event_exists?)
                                                      .and_return(true)

        registry_module.register do
          events(simple_event: 1, multi_event: 2) do |context|
            context
          end

          events(no_block_event: 3)

          transformation(:multi_event) do
            { a: 'b' }
          end
        end
      end

      describe '.events' do
        it 'fails when same event ID already exists' do
          expect do
            registry_module.register do
              events(same_id_event: 1)
            end
          end.to raise_error("Event with id `1` was already registered")
        end

        it 'fails when same event name already exists' do
          expect do
            registry_module.register do
              events(simple_event: 123)
            end
          end.to raise_error("Event with name `simple_event` was already registered")
        end
      end

      describe '.registered_events' do
        it 'returns hash with registered event names and ids' do
          expect(registry_module.registered_events).to eq({
            'simple_event' => 1,
            'multi_event' => 2,
            'no_block_event' => 3
          })
        end
      end

      describe '.registered_transformations' do
        it 'returns all registered transformation blocks for given event' do
          expect(registry_module.registered_transformations(:no_block_event).size).to eq(0)
          expect(registry_module.registered_transformations(:simple_event).size).to eq(1)
          expect(registry_module.registered_transformations(:multi_event).size).to eq(2)
        end
      end
    end
  end
end
