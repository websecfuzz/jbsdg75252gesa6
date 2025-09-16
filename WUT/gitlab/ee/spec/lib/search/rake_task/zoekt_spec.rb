# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::RakeTask::Zoekt, :silence_stdout, feature_category: :global_search do
  let(:stdout_logger) { instance_double(Logger) }
  let(:task_executor_service) { instance_double(Search::Zoekt::RakeTaskExecutorService) }

  before do
    allow(described_class).to receive(:stdout_logger).and_return(stdout_logger)
    allow(task_executor_service).to receive(:execute)
    allow(Search::Zoekt::RakeTaskExecutorService).to receive(:new).and_return(task_executor_service)
    allow(stdout_logger).to receive(:info)
    # Stub internal methods to prevent actual system behavior
    allow(described_class).to receive(:clear_screen)
    allow(described_class).to receive(:sleep)
  end

  describe '.info' do
    before do
      # Make run_with_interval yield once and then raise Interrupt to stop the loop
      allow(described_class).to receive(:run_with_interval).and_call_original
      allow(described_class).to receive(:loop) do |&block|
        block.call
        raise Interrupt
      end
    end

    it 'creates task executor with extended_mode: true when watch_interval is nil' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: { extended_mode: true })
        .and_return(task_executor_service)

      described_class.info(name: 'test', watch_interval: nil)
    end

    it 'creates task executor with extended_mode: false when interval is present' do
      allow(Gitlab::Utils).to receive(:to_boolean).and_return(false)

      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: { extended_mode: false })
        .and_return(task_executor_service)

      described_class.info(name: 'test', watch_interval: '5', extended: 'false')
    end

    it 'executes the info task' do
      expect(task_executor_service).to receive(:execute).with(:info)

      described_class.info(name: 'test')
    end

    it 'does not enter the loop when watch_interval is nil' do
      expect(described_class).not_to receive(:loop)

      described_class.info(name: 'test', watch_interval: nil)
    end

    it 'enters the loop when watch_interval is positive' do
      expect(described_class).to receive(:loop)

      described_class.info(name: 'test', watch_interval: '5')
    end
  end
end
