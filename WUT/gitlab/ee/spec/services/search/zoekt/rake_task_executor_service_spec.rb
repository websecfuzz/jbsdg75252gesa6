# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::RakeTaskExecutorService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:options) { { custom_option: 'value' } }
  let(:service) { described_class.new(logger: logger, options: options) }

  describe '#execute' do
    it 'raises an exception when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::Zoekt::RakeTaskExecutorService::TASKS', [:foo])

      expect { service.execute(:foo) }.to raise_error(NotImplementedError)
    end

    it 'delegates info task to InfoService with options' do
      info_service = instance_double(Search::Zoekt::InfoService, execute: true)
      expect(Search::Zoekt::InfoService).to receive(:new).with(logger: logger,
        options: options).and_return(info_service)

      service.execute(:info)
    end
  end
end
