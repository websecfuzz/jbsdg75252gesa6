# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:zoekt namespace rake tasks', :silence_stdout, feature_category: :global_search do
  before do
    Rake.application.rake_require 'tasks/gitlab/zoekt'
  end

  shared_examples 'rake task executor task' do |task|
    it 'calls rake task executor' do
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(task)
      end

      run_rake_task("gitlab:zoekt:#{task}")
    end
  end

  describe 'gitlab:zoekt:info' do
    include_examples 'rake task executor task', :info
  end

  describe 'gitlab:zoekt:install' do
    context 'when no arguments are provided' do
      it 'raises error' do
        expect { run_rake_task('gitlab:zoekt:install') }.to raise_error(/Please specify the directory/)
      end
    end

    context 'when arguments are provided' do
      context 'when make is not found' do
        before do
          allow(Gitlab::Utils).to receive(:which).and_return(nil)
        end

        it 'raises error' do
          expect { run_rake_task('gitlab:zoekt:install', '/test/dir') }.to raise_error(/Couldn't find a 'make' binary/)
        end
      end

      context 'when make is found' do
        before do
          allow(Gitlab::Utils).to receive(:which).and_return('gmake')
          allow(main_object).to receive(:run_command!).with(%w[gmake build-unified])
          allow(Dir).to receive(:chdir).with('/test/dir').and_yield
        end

        context 'when repo arg is not provided' do
          it 'calls checkout_or_clone_version with default repo' do
            expect(main_object).to receive(:checkout_or_clone_version)
                                     .with(version: Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp,
                                       repo: 'https://gitlab.com/gitlab-org/gitlab-zoekt-indexer.git',
                                       target_dir: '/test/dir',
                                       clone_opts: %w[--depth 1]
                                     )

            run_rake_task('gitlab:zoekt:install', '/test/dir')
          end
        end

        context 'when repo arg is also provided' do
          it 'calls checkout_or_clone_version with given repo' do
            expect(main_object).to receive(:checkout_or_clone_version)
                                     .with(version: Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp,
                                       repo: 'repo',
                                       target_dir: '/test/dir',
                                       clone_opts: %w[--depth 1]
                                     )

            run_rake_task('gitlab:zoekt:install', '/test/dir', 'repo')
          end
        end
      end
    end
  end

  describe 'watch functionality in rake task' do
    it 'executes the rake task normally without watch mode when no interval is provided' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info")
    end

    it 'executes the rake task normally when interval is zero' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "0")
    end

    it 'executes the rake task normally when interval is negative' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "-1")
    end
  end
end
