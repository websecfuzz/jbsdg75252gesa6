# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::GitGuardian, feature_category: :integrations do
  include FakeBlobHelpers

  let_it_be(:project) { create(:project, :repository) }
  let(:token) { 'test-token' }

  let(:file_paths) { %w[README.md test_path/file.md test.yml] }
  let(:blobs) { file_paths.map { |path| fake_blob(path: path) } }
  let(:repository_url) { Gitlab::UrlBuilder.build(project, port: nil, protocol: false).delete_prefix('//') }

  subject(:integration) { create(:git_guardian_integration, project: project, token: token) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:token) }

    context 'when inactive' do
      before do
        integration.active = false
      end

      it { is_expected.not_to validate_presence_of(:token) }
    end
  end

  describe '#execute' do
    context 'when executing' do
      it 'sends a GitGuardian request through our client class' do
        expect_next_instance_of(::Gitlab::GitGuardian::Client) do |client|
          expect(client).to receive(:execute).with(blobs, repository_url).and_return([])
        end

        integration.execute(blobs, repository_url)
      end
    end
  end
end
