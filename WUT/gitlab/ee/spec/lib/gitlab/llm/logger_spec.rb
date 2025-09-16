# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Logger, feature_category: :ai_abstraction_layer do
  describe "log_level" do
    subject(:log_level) { described_class.build.level }

    context 'when LLM_DEBUG is not set' do
      it { is_expected.to eq ::Logger::INFO }
    end

    context 'when LLM_DEBUG=true' do
      before do
        stub_env('LLM_DEBUG', true)
      end

      it { is_expected.to eq ::Logger::DEBUG }
    end

    context 'when LLM_DEBUG=false' do
      before do
        stub_env('LLM_DEBUG', false)
      end

      it { is_expected.to eq ::Logger::INFO }
    end
  end

  describe "#conditional_info" do
    let_it_be(:user) { create(:user) }
    let(:logger) { described_class.build }

    context 'with expanded_ai_logging switched on' do
      it 'logs on info level' do
        expect(logger).to receive(:info)
          .with({
            message: 'test',
            klass: 'Gitlab::Llm',
            event_name: 'received_response',
            ai_component: 'ai_abstraction_layer',
            options: { prompt: 'prompt' }
          })

        logger.conditional_info(user,
          message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          options: { prompt: 'prompt' })
      end
    end

    context 'with expanded_ai_logging switched off' do
      before do
        stub_feature_flags(expanded_ai_logging: false)
      end

      it 'logs on info level with limited params' do
        expect(logger).to receive(:info).with(message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer')

        logger.conditional_info(user,
          message: 'test',
          klass: 'Gitlab::Llm',
          event_name: 'received_response',
          ai_component: 'ai_abstraction_layer',
          prompt: 'prompt')
      end
    end
  end
end
