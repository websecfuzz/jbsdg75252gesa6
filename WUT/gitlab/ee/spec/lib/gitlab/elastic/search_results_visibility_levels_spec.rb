# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'visibility_levels', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:limit_project_ids) { [project.id] }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility levels', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be_with_reload(:internal_project) do
      create(:project, :internal, :repository, :wiki_repo, description: "Internal project")
    end

    let_it_be_with_reload(:private_project1) do
      create(:project, :private, :repository, :wiki_repo, description: "Private project")
    end

    let_it_be_with_reload(:private_project2) do
      create(:project, :private, :repository, :wiki_repo, developers: user,
        description: "Private project where I'm a member")
    end

    let_it_be_with_reload(:public_project) do
      create(:project, :public, :repository, :wiki_repo, description: "Public project")
    end

    let(:limit_project_ids) { [private_project2.id] }

    before do
      Elastic::ProcessInitialBookkeepingService.backfill_projects!(internal_project,
        private_project1, private_project2, public_project)

      ensure_elasticsearch_index!
    end

    describe 'issues' do
      shared_examples 'issues respect visibility' do
        it 'finds right set of issues' do
          issue_1 = create :issue, project: internal_project, title: "Internal project"
          create :issue, project: private_project1, title: "Private project"
          issue_3 = create :issue, project: private_project2, title: "Private project where I'm a member"
          issue_4 = create :issue, project: public_project, title: "Public project"

          ensure_elasticsearch_index!

          # Authenticated search
          results = described_class.new(user, 'project', limit_project_ids)
          issues = results.objects('issues')

          expect(issues).to include issue_1
          expect(issues).to include issue_3
          expect(issues).to include issue_4
          expect(results.issues_count).to eq 3

          # Unauthenticated search
          results = described_class.new(nil, 'project', [])
          issues = results.objects('issues')

          expect(issues).to include issue_4
          expect(results.issues_count).to eq 1
        end

        context 'when different issue descriptions', :aggregate_failures do
          let(:examples) do
            code_examples.merge(
              'screen' => 'Screenshots or screen recordings',
              'problem' => 'Problem to solve'
            )
          end

          include_context 'with code examples' do
            before do
              examples.values.uniq.each do |description|
                sha = Digest::SHA256.hexdigest(description)
                create :issue, project: private_project2, title: sha, description: description
              end

              ensure_elasticsearch_index!
            end

            it 'finds all examples' do
              examples.each do |search_term, description|
                sha = Digest::SHA256.hexdigest(description)

                results = described_class.new(user, search_term, limit_project_ids)
                issues = results.objects('issues')
                expect(issues.map(&:title)).to include(sha), "failed to find #{search_term}"
              end
            end
          end
        end
      end

      it_behaves_like 'issues respect visibility'
    end

    describe 'milestones' do
      let_it_be_with_reload(:milestone_1) { create(:milestone, project: internal_project, title: "Internal project") }
      let_it_be_with_reload(:milestone_2) { create(:milestone, project: private_project1, title: "Private project") }
      let_it_be_with_reload(:milestone_3) do
        create(:milestone, project: private_project2, title: "Private project which user is member")
      end

      let_it_be_with_reload(:milestone_4) { create(:milestone, project: public_project, title: "Public project") }

      before do
        Elastic::ProcessInitialBookkeepingService.track!(milestone_1, milestone_2, milestone_3, milestone_4)
        ensure_elasticsearch_index!
      end

      it_behaves_like 'a paginated object', 'milestones'

      context 'when project ids are present' do
        context 'when authenticated' do
          context 'when user and merge requests are disabled in a project' do
            it 'returns right set of milestones' do
              private_project2.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
              private_project2.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
              public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
              public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
              internal_project.project_feature.update!(issues_access_level: ProjectFeature::DISABLED)
              ensure_elasticsearch_index!

              projects = user.authorized_projects
              results = described_class.new(user, 'project', projects.pluck_primary_key)
              milestones = results.objects('milestones')

              expect(milestones).to match_array([milestone_1, milestone_3])
            end
          end

          context 'when user is admin' do
            context 'when admin mode enabled', :enable_admin_mode do
              it 'returns right set of milestones' do
                user.update!(admin: true)
                public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
                public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
                internal_project.project_feature.update!(issues_access_level: ProjectFeature::DISABLED)
                internal_project.project_feature.update!(merge_requests_access_level: ProjectFeature::DISABLED)
                ensure_elasticsearch_index!

                results = described_class.new(user, 'project', :any)
                milestones = results.objects('milestones')

                expect(milestones).to match_array([milestone_2, milestone_3, milestone_4])
              end
            end
          end

          context 'when user can read milestones' do
            it 'returns right set of milestones' do
              # Authenticated search
              projects = user.authorized_projects
              results = described_class.new(user, 'project', projects.pluck_primary_key)
              milestones = results.objects('milestones')

              expect(milestones).to match_array([milestone_1, milestone_3, milestone_4])
            end
          end
        end
      end

      context 'when not authenticated' do
        it 'returns right set of milestones' do
          results = described_class.new(nil, 'project', [])
          milestones = results.objects('milestones')

          expect(milestones).to include milestone_4
          expect(results.milestones_count).to eq 1
        end
      end

      context 'when project_ids is not present' do
        context 'when project_ids is :any' do
          it 'returns all milestones' do
            results = described_class.new(user, 'project', :any)

            milestones = results.objects('milestones')

            expect(results.milestones_count).to eq(4)

            expect(milestones).to include(milestone_1)
            expect(milestones).to include(milestone_2)
            expect(milestones).to include(milestone_3)
            expect(milestones).to include(milestone_4)
          end
        end

        context 'when authenticated' do
          it 'returns right set of milestones' do
            results = described_class.new(user, 'project', [])
            milestones = results.objects('milestones')

            expect(milestones).to include(milestone_1)
            expect(milestones).to include(milestone_4)
            expect(results.milestones_count).to eq(2)
          end
        end

        context 'when not authenticated' do
          it 'returns right set of milestones' do
            # Should not be returned because issues and merge requests feature are disabled
            other_public_project = create(:project, :public)
            create(:milestone, project: other_public_project, title: 'Public project milestone 1')
            other_public_project.project_feature.update!(merge_requests_access_level: ProjectFeature::PRIVATE)
            other_public_project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
            # Should be returned because only issues is disabled
            other_public_project_1 = create(:project, :public)
            milestone_5 = create(:milestone, project: other_public_project_1, title: 'Public project milestone 2')
            other_public_project_1.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
            ensure_elasticsearch_index!

            results = described_class.new(nil, 'project', [])
            milestones = results.objects('milestones')

            expect(milestones).to match_array([milestone_4, milestone_5])
            expect(results.milestones_count).to eq(2)
          end
        end
      end
    end

    describe 'projects' do
      it_behaves_like 'a paginated object', 'projects'

      it 'finds right set of projects' do
        internal_project
        private_project1
        private_project2
        public_project

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project', limit_project_ids)
        milestones = results.objects('projects')

        expect(milestones).to include internal_project
        expect(milestones).to include private_project2
        expect(milestones).to include public_project
        expect(results.projects_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project', [])
        projects = results.objects('projects')

        expect(projects).to include public_project
        expect(results.projects_count).to eq 1
      end

      it 'returns 0 results for count only query' do
        public_project

        ensure_elasticsearch_index!

        results = described_class.new(user, '"noresults"')
        count = results.formatted_count('projects')
        expect(count).to eq('0')
      end
    end

    describe 'merge requests' do
      it 'finds right set of merge requests' do
        merge_request_1 = create :merge_request, target_project: internal_project, source_project: internal_project,
          title: "Internal project"
        create :merge_request, target_project: private_project1, source_project: private_project1,
          title: "Private project"
        merge_request_3 = create :merge_request, target_project: private_project2, source_project: private_project2,
          title: "Private project where I'm a member"
        merge_request_4 = create :merge_request, target_project: public_project, source_project: public_project,
          title: "Public project"

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'project', limit_project_ids)
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_1
        expect(merge_requests).to include merge_request_3
        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'project', [])
        merge_requests = results.objects('merge_requests')

        expect(merge_requests).to include merge_request_4
        expect(results.merge_requests_count).to eq 1
      end
    end

    describe 'wikis', :sidekiq_inline do
      before do
        [public_project, internal_project, private_project1, private_project2].each do |project|
          project.wiki.create_page('index_page', 'term')
          project.wiki.index_wiki_blobs
        end

        ensure_elasticsearch_index!
      end

      it 'finds the right set of wiki blobs' do
        # Authenticated search
        results = described_class.new(user, 'term', limit_project_ids)
        blobs = results.objects('wiki_blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.wiki_blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'term', [])
        blobs = results.objects('wiki_blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.wiki_blobs_count).to eq 1
      end
    end

    describe 'commits', :sidekiq_inline do
      it 'finds right set of commits' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file-commits',
            'commits test',
            message: 'commits test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'commits test', limit_project_ids)
        commits = results.objects('commits')

        expect(commits.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.commits_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'commits test', [])
        commits = results.objects('commits')

        expect(commits.first.project).to eq public_project
        expect(results.commits_count).to eq 1
      end
    end

    describe 'blobs', :sidekiq_inline do
      it 'finds right set of blobs' do
        [internal_project, private_project1, private_project2, public_project].each do |project|
          project.repository.create_file(
            user,
            'test-file-blobs',
            'blobs test',
            message: 'blobs test',
            branch_name: 'master'
          )

          project.repository.index_commits_and_blobs
        end

        ensure_elasticsearch_index!

        # Authenticated search
        results = described_class.new(user, 'blobs test', limit_project_ids)
        blobs = results.objects('blobs')

        expect(blobs.map(&:project)).to match_array [internal_project, private_project2, public_project]
        expect(results.blobs_count).to eq 3

        # Unauthenticated search
        results = described_class.new(nil, 'blobs test', [])
        blobs = results.objects('blobs')

        expect(blobs.first.project).to eq public_project
        expect(results.blobs_count).to eq 1
      end
    end
  end
end
