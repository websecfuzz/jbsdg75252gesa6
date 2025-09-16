# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Concerns::Logger, feature_category: :ai_abstraction_layer do
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:user) { build(:user) }
  let(:logged_params) { { message: 'test', event_name: 'test', ai_component: 'test', tool_name: 'test' } }
  let(:dummy_class) do
    Class.new do
      include Gitlab::Llm::Concerns::Logger

      def method_with_error(logged_params)
        log_error(**logged_params)
      end

      def method_with_info(logged_params)
        log_info(**logged_params)
      end

      def method_with_warn(logged_params)
        log_warn(**logged_params)
      end

      def method_with_conditional_info(user, logged_params)
        log_conditional_info(user, **logged_params)
      end
    end
  end

  subject(:instance) { dummy_class.new }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
  end

  describe '#log_conditional_info' do
    it 'calls logger with conditional_info method' do
      expect(logger).to receive(:conditional_info).with(user, klass: instance.class.to_s, **logged_params)

      instance.method_with_conditional_info(user, **logged_params)
    end
  end

  describe '#log_info' do
    it 'calls logger with info method' do
      expect(logger).to receive(:info).with(klass: instance.class.to_s, **logged_params)

      instance.method_with_info(**logged_params)
    end
  end

  describe '#log_error' do
    it 'calls logger with error method' do
      expect(logger).to receive(:error).with(klass: instance.class.to_s, **logged_params)

      instance.method_with_error(**logged_params)
    end
  end

  describe '#log_warn' do
    it 'calls logger with warn method' do
      expect(logger).to receive(:warn).with(klass: instance.class.to_s, **logged_params)

      instance.method_with_warn(**logged_params)
    end
  end

  context 'with unauthorized parameters' do
    let(:logged_params) { { message: 'test', event_name: 'test', ai_component: 'test', bad_param: 'test' } }

    it 'does not call logger with info method' do
      expect(logger).not_to receive(:info)

      expect { instance.method_with_info(**logged_params) }.to raise_error(ArgumentError, /not known keys/)
    end

    context 'with bad param type' do
      let(:logged_params) { { message: 'test', event_name: 'test', ai_component: 'test', tool_name: { test: 'test' } } }

      it 'does call logger with info method and adds warn log' do
        expect(logger).to receive(:warn)
        expect(logger).to receive(:info).with(a_hash_including(logged_params))

        instance.method_with_info(**logged_params)
      end
    end
  end
end
