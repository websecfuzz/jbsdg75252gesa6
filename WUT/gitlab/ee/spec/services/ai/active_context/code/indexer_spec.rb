# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::Indexer, feature_category: :global_search do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:connection) { create(:ai_active_context_connection) }
  let_it_be(:repository) do
    create(:ai_active_context_code_repository, active_context_connection: connection, project: project)
  end

  let_it_be(:collection) do
    create(:ai_active_context_collection, name: 'gitlab_active_context_code', connection: connection)
  end

  let(:adapter) do
    instance_double(::ActiveContext::Databases::Elasticsearch::Adapter, name: 'elasticsearch', connection: connection)
  end

  let(:indexer) { described_class.new(repository) }

  subject(:run) { indexer.run }

  before do
    allow(::ActiveContext).to receive(:adapter).and_return(adapter)
    allow(indexer).to receive(:to_commit).and_return(instance_double(Commit, id: '000'))
  end

  describe '#run' do
    context 'when adapter is available' do
      context 'when command is executed' do
        let(:env_vars) { { "GITLAB_INDEXER_MODE" => "chunk" } }
        let(:expected_options) do
          {
            from_sha: Gitlab::Git::SHA1_BLANK_SHA,
            to_sha: '000',
            project_id: project.id,
            partition_name: collection.name,
            partition_number: collection.partition_for(project.id),
            gitaly_config: {
              address: Gitlab::GitalyClient.address(project.repository_storage),
              storage: project.repository_storage,
              relative_path: project.repository.relative_path,
              project_path: project.full_path
            },
            timeout: described_class::TIMEOUT
          }
        end

        let(:expected_command) do
          [
            Gitlab.config.elasticsearch.indexer_path,
            '-adapter', 'elasticsearch',
            '-connection', ::Gitlab::Json.generate(connection.options),
            '-options', ::Gitlab::Json.generate(expected_options)
          ]
        end

        it 'calls the indexer with the correct command' do
          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(['output', 0])

          run
        end
      end

      context 'when indexer command succeeds' do
        let(:indexer_output) do
          <<~OUTPUT
            Some output
            --section-start--
            id
            chunk_id_1
            chunk_id_2
            chunk_id_3
            --section-start--
            Other section
          OUTPUT
        end

        before do
          allow(Gitlab::Popen).to receive(:popen).and_return([indexer_output, 0])
        end

        it 'sets the last_commit and returns extracted chunk IDs' do
          expect(repository).to receive(:update!).with(last_commit: '000')

          expect(run).to eq(%w[chunk_id_1 chunk_id_2 chunk_id_3])
        end
      end

      context 'when indexer command fails' do
        let(:error_output) { 'Command failed with error' }

        before do
          allow(Gitlab::Popen).to receive(:popen).and_return([error_output, 1])
        end

        it 'raises an exception' do
          expect { run }.to raise_error(described_class::Error, "Indexer failed: #{error_output}")
        end
      end
    end

    context 'when adapter is not available' do
      before do
        allow(::ActiveContext).to receive(:adapter).and_return(nil)
      end

      it 'raises an error' do
        expect { run }.to raise_error(described_class::Error, 'Adapter not set')
      end
    end
  end
end
