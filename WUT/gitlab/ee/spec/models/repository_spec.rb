# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repository, feature_category: :source_code_management do
  include RepoHelpers
  include ::EE::GeoHelpers

  before do
    stub_const('TestBlob', Struct.new(:path))
  end

  let_it_be(:primary_node)   { create(:geo_node, :primary) }
  let_it_be(:secondary_node) { create(:geo_node) }

  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository }

  def create_remote_branch(remote_name, branch_name, target)
    repository.write_ref("refs/remotes/#{remote_name}/#{branch_name}", target.id)
  end

  describe 'delegated methods' do
    subject { repository }

    it { is_expected.to delegate_method(:checksum).to(:raw_repository) }
    it { is_expected.to delegate_method(:find_remote_root_ref).to(:raw_repository) }
  end

  describe '#after_sync' do
    it 'expires repository cache' do
      expect(repository).to receive(:expire_all_method_caches)
      expect(repository).to receive(:expire_branch_cache)
      expect(repository).to receive(:expire_content_cache)

      repository.after_sync
    end

    it 'does not call expire_branch_cache if repository does not exist' do
      allow(repository).to receive(:exists?).and_return(false)

      expect(repository).to receive(:expire_all_method_caches)
      expect(repository).not_to receive(:expire_branch_cache)
      expect(repository).to receive(:expire_content_cache)

      repository.after_sync
    end
  end

  describe '#after_create' do
    context 'when repository is attached to a personal snippet' do
      let(:repository) { create(:personal_snippet).repository }

      it 'does not raise an error for onboarding considerations' do
        expect { repository.after_create }.not_to raise_error
      end
    end
  end

  describe '#fetch_upstream' do
    let(:url) { "http://example.com" }

    it 'fetches the URL without creating a remote' do
      expect(repository)
        .to receive(:fetch_remote)
        .with(url, refmap: ['+refs/heads/*:refs/remotes/upstream/*'], ssh_auth: nil, forced: true)
        .and_return(nil)

      repository.fetch_upstream(url, forced: true)
    end
  end

  describe "Elastic search", :elastic do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    describe "class method find_commits_by_message_with_elastic" do
      it "returns commits", :sidekiq_might_not_need_inline do
        project = create :project, :repository
        project1 = create :project, :repository

        project.repository.index_commits_and_blobs
        project1.repository.index_commits_and_blobs

        ensure_elasticsearch_index!

        expect(described_class.find_commits_by_message_with_elastic('initial').first).to be_a(Commit)
        expect(described_class.find_commits_by_message_with_elastic('initial').count).to eq(2)
        expect(described_class.find_commits_by_message_with_elastic('initial').total_count).to eq(2)
      end
    end

    describe "find_commits_by_message_with_elastic" do
      it "returns commits", :sidekiq_might_not_need_inline do
        project = create :project, :repository

        project.repository.index_commits_and_blobs
        ensure_elasticsearch_index!

        expect(project.repository.find_commits_by_message_with_elastic('initial').first).to be_a(Commit)
        expect(project.repository.find_commits_by_message_with_elastic('initial').count).to eq(1)
        expect(project.repository.find_commits_by_message_with_elastic('initial').total_count).to eq(1)
      end
    end
  end

  describe '#upstream_branches' do
    it 'returns branches from the upstream remote' do
      masterrev = repository.find_branch('master').dereferenced_target
      create_remote_branch('upstream', 'upstream_branch', masterrev)

      expect(repository.upstream_branches.size).to eq(1)
      expect(repository.upstream_branches.first).to be_an_instance_of(Gitlab::Git::Branch)
      expect(repository.upstream_branches.first.name).to eq('upstream_branch')
    end
  end

  describe '#keep_around' do
    let(:sha) { sample_commit.id }
    let(:event) { instance_double('::Repositories::KeepAroundRefsCreatedEvent') }
    let(:event_data) { { project_id: project.id } }

    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary_node)
      end

      context 'when a single SHA is passed' do
        it 'publishes Repositories::KeepAroundRefsCreatedEvent' do
          allow(::Repositories::KeepAroundRefsCreatedEvent)
            .to receive(:new)
            .with(data: event_data)
            .and_return(event)

          expect(Gitlab::EventStore).to receive(:publish).with(event).once

          repository.keep_around(sha, source: 'repository_spec')
        end

        it 'creates a Geo::Event', :sidekiq_inline do
          expect { repository.keep_around(sha, source: 'repository_spec') }
            .to change { ::Geo::Event.where(event_name: :updated).count }.by(1)
        end
      end

      context 'when multiple SHAs are passed' do
        it 'publishes exactly one Repositories::KeepAroundRefsCreatedEvent' do
          allow(::Repositories::KeepAroundRefsCreatedEvent)
            .to receive(:new)
            .with(data: event_data)
            .and_return(event)

          expect(Gitlab::EventStore).to receive(:publish).with(event).once

          repository.keep_around(sha, sample_big_commit.id, source: 'repository_spec')
        end

        it 'creates exactly one Geo::Event', :sidekiq_inline do
          expect { repository.keep_around(sha, sample_big_commit.id, source: 'repository_spec') }
            .to change { ::Geo::Event.where(event_name: :updated).count }.by(1)
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      context 'when multiple SHAs are passed' do
        it 'publishes a Repositories::KeepAroundRefsCreatedEvent' do
          allow(::Repositories::KeepAroundRefsCreatedEvent)
            .to receive(:new)
            .with(data: event_data)
            .and_return(event)

          expect(Gitlab::EventStore).to receive(:publish).with(event)

          repository.keep_around(sha, sample_big_commit.id, source: 'repository_spec')
        end

        it 'does not create a Geo::Event', :sidekiq_inline do
          expect { repository.keep_around(sha, source: 'repository_spec') }
            .not_to change { ::Geo::Event.count }
        end
      end

      context "when no SHA is passed" do
        it 'does not publish a Repositories::KeepAroundRefsCreatedEvent' do
          allow(Gitlab::EventStore).to receive(:publish)

          expect(Gitlab::EventStore).not_to have_received(:publish).with(instance_of(::Repositories::KeepAroundRefsCreatedEvent))

          repository.keep_around(nil, source: 'repository_spec')
        end

        it 'does not create a Geo::Event', :sidekiq_inline do
          expect { repository.keep_around(nil, source: 'repository_spec') }
          .not_to change { ::Geo::Event.count }
        end
      end
    end
  end

  describe '#code_owners_blob' do
    it 'returns nil if there is no codeowners file' do
      expect(repository.code_owners_blob(ref: 'master')).to be_nil
    end

    it 'returns the content of the codeowners file when it is found' do
      expect(repository.code_owners_blob(ref: 'with-codeowners').data).to include('example CODEOWNERS file')
    end

    it 'requests the CODOWNER blobs in batch in the correct order' do
      expect(repository).to receive(:blobs_at)
                              .with([%w[master CODEOWNERS],
                                %w[master docs/CODEOWNERS],
                                %w[master .gitlab/CODEOWNERS]])
                              .and_call_original

      repository.code_owners_blob(ref: 'master')
    end
  end

  describe '#after_change_head' do
    shared_examples_for 'a repository change head' do
      it 'creates a geo event on a Geo primary' do
        stub_current_geo_node(primary_node)

        event_params = {
          event_name: 'updated',
          replicable_name: replicable_name
        }

        expect { repository.after_change_head }
          .to change { ::Geo::Event.where(event_params).count }.by(1)
      end

      it 'does not create a geo event on a Geo secondary' do
        stub_current_geo_node(secondary_node)

        expect { repository.after_change_head }
          .not_to change { ::Geo::Event.count }
      end
    end

    context 'for a project repository' do
      let(:repository) { project.repository }
      let(:replicable_name) { 'project_repository' }

      it_behaves_like 'a repository change head'
    end

    context 'for a project wiki repository' do
      let(:repository) { project.wiki.repository }
      let(:replicable_name) { 'project_wiki_repository' }

      before do
        project.create_wiki
      end

      it_behaves_like 'a repository change head'
    end

    context 'for a group wiki repository' do
      let(:group_wiki) { create(:group_wiki) }
      let(:repository) { group_wiki.repository }
      let(:replicable_name) { 'group_wiki_repository' }

      before do
        group_wiki.create_wiki_repository
      end

      it_behaves_like 'a repository change head'
    end

    context 'for a design management repository' do
      let(:design_management_repository) { create(:design_management_repository) }
      let(:repository) { design_management_repository.repository }
      let(:replicable_name) { 'design_management_repository' }

      it_behaves_like 'a repository change head'
    end

    context 'for a project snippet repository' do
      let(:project_snippet) { create(:project_snippet) }
      let(:repository) { project_snippet.repository }
      let(:replicable_name) { 'snippet_repository' }

      before do
        project_snippet.create_repository
      end

      it_behaves_like 'a repository change head'
    end

    context 'for a personal snippet repository' do
      let(:personal_snippet) { create(:personal_snippet) }
      let(:repository) { personal_snippet.repository }
      let(:replicable_name) { 'snippet_repository' }

      before do
        personal_snippet.create_repository
      end

      it_behaves_like 'a repository change head'
    end
  end

  describe "#insights_config_for" do
    context 'when no config file exists' do
      it 'returns nil if does not exist' do
        expect(repository.insights_config_for(repository.root_ref)).to be_nil
      end
    end

    it 'returns nil for an empty repository' do
      allow(repository).to receive(:empty?).and_return(true)

      expect(repository.insights_config_for(repository.root_ref)).to be_nil
    end

    it 'returns a valid Insights config file' do
      project = create(:project, :custom_repo, files: { Gitlab::Insights::CONFIG_FILE_PATH => "monthlyBugsCreated:\n  title: My chart" })

      expect(project.repository.insights_config_for(project.repository.root_ref)).to eq("monthlyBugsCreated:\n  title: My chart")
    end
  end

  describe '#lfs_enabled?' do
    subject { repository.lfs_enabled? }

    context 'for a group wiki repository' do
      let(:repository) { build_stubbed(:group_wiki).repository }

      it 'returns false' do
        is_expected.to be_falsy
      end
    end
  end

  describe '#update_root_ref' do
    let(:url) { 'http://git.example.com/remote-repo.git' }
    let(:auth) { 'Basic secret' }

    it 'updates the default branch when HEAD has changed' do
      stub_find_remote_root_ref(repository, ref: 'feature')

      expect { repository.update_root_ref(url, auth) }
        .to change { project.default_branch }
        .from('master')
        .to('feature')
    end

    it 'always updates the default branch even when HEAD does not change' do
      stub_find_remote_root_ref(repository, ref: 'master')

      expect(repository).to receive(:change_head).with('master').and_call_original

      repository.update_root_ref(url, auth)

      expect(project.default_branch).to eq('master')
    end

    it 'does not update the default branch when HEAD does not exist' do
      stub_find_remote_root_ref(repository, ref: 'foo')

      expect { repository.update_root_ref(url, auth) }
        .not_to change { project.default_branch }
    end

    context 'when project repo is missing' do
      before do
        allow(repository).to receive(:find_remote_root_ref)
          .with(url, auth)
          .and_raise(Gitlab::Git::Repository::NoRepository)
      end

      it 'logs a message' do
        expect(Gitlab::AppLogger)
          .to receive(:info)
          .with(/Error updating root ref for repository/)

        repository.update_root_ref(url, auth)
      end

      it 'returns nil when NoRepository exception is raised' do
        expect(repository.update_root_ref(url, auth)).to be_nil
      end

      it 'does not raise error' do
        expect { repository.update_root_ref(url, auth) }.not_to raise_error
      end
    end

    def stub_find_remote_root_ref(repository, ref:)
      allow(repository)
        .to receive(:find_remote_root_ref)
        .with(url, auth)
        .and_return(ref)
    end
  end

  describe '.group' do
    let_it_be(:group) { create(:group, :wiki_repo) }
    let_it_be(:project_within_group) { create(:project, :repository, group: group) }
    let_it_be(:project_not_within_group) { create(:project, :repository) }
    let(:repository_of_group_wiki) { group.wiki.repository }
    let(:repository_of_project_wiki) { project_not_within_group.wiki.repository }
    let(:repository_of_project_within_group) { project_within_group.repository }
    let(:repository_of_project_not_within_group) { project_not_within_group.repository }

    using RSpec::Parameterized::TableSyntax

    where(:repository, :expected_value) do
      ref(:repository_of_group_wiki)                | ref(:group)
      ref(:repository_of_project_wiki)              | nil
      ref(:repository_of_project_within_group)      | ref(:group)
      ref(:repository_of_project_not_within_group)  | nil
    end

    with_them do
      it { expect(repository.group).to eq(expected_value) }
    end
  end

  describe '#commit_files' do
    let_it_be_with_refind(:project) { create(:project, :repository) }
    let(:target_sha) { repository.commit('master').sha }
    let(:user) { project.owner }
    let(:expected_params) do
      [
        user, # user
        'master', # branch_name
        'commit message', # commit_message
        [], # actions
        'author email', # author_email
        'author name', # author_name
        nil, # start_branch_name
        nil, # start_repository
        true, # force
        nil, # start_sha
        expected_sign, # sign
        target_sha # target_sha
      ]
    end

    let(:params) do
      {
        branch_name: 'master',
        message: 'commit message',
        author_name: 'author name',
        author_email: 'author email',
        actions: [],
        force: true
      }
    end

    subject(:commit_files) do
      repository.commit_files(user, **params)
    end

    using RSpec::Parameterized::TableSyntax
    where(
      :repositories_web_based_commit_signing,
      :web_based_commit_signing_enabled,
      :use_web_based_commit_signing_enabled,
      :expected_sign) do
      true  | false | true  | false
      true  | true  | true  | true
      true  | false | false | true
      true  | true  | false | true
      false | false | true  | true
      false | true  | true  | true
      false | false | false | true
      false | true  | false | true
    end

    with_them do
      before do
        stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
        stub_feature_flags(use_web_based_commit_signing_enabled: use_web_based_commit_signing_enabled)
        project.web_based_commit_signing_enabled = web_based_commit_signing_enabled
      end

      it 'calls UserCommitFiles with the expected value for sign' do
        expect_next_instance_of(Gitlab::GitalyClient::OperationService) do |client|
          expect(client).to receive(:user_commit_files).with(*expected_params)
        end

        commit_files
      end
    end
  end
end
