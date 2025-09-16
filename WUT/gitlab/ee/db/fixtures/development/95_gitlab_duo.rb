# frozen_string_literal: true

# This class is responsible for seeding group/project resources for testing GitLab Duo features.
# See https://docs.gitlab.com/ee/development/ai_features/#seed-project-and-group-resources-for-testing-and-evaluation
# for more information.
class Gitlab::Seeder::GitLabDuo # rubocop:disable Style/ClassAndModuleChildren -- this is a seed script
  GROUP_PATH = 'gitlab-duo'
  PROJECT_PATH = 'test'
  PROJECT_CLONE_URL = "https://gitlab.com/gitlab-org/modelops/ai-model-validation-and-research/ai-evaluation/test-repo.git"
  ID_BASE = 1_000_000

  def seed!
    user = User.find_by_username('root')
    puts "Seeding resources to #{GROUP_PATH} group..."

    ApplicationRecord.transaction do
      group = FactoryBot.create(:group, :public, id: ID_BASE, name: 'GitLab Duo', path: GROUP_PATH)
      group.add_owner(user)

      epic = FactoryBot.create(:epic,
        id: ID_BASE,
        iid: 1,
        group: group,
        author: user,
        title: 'HTTP server examples for all programming languages',
        description: 'This is an epic to add HTTP server examples for all programming languages.'
      )
      # Create project
      project = FactoryBot.create(:project, :public, id: ID_BASE, name: 'Test', path: PROJECT_PATH,
        creator: user, namespace: group)
      project.add_owner(user)
      # Create repository
      repo = Gitlab::GlRepository::PROJECT.repository_for(project).raw
      create_git_bundle do |bundle_path|
        repo.create_from_bundle(bundle_path)
      end
      # Create project-level resources
      issue = FactoryBot.create(:issue,
        id: ID_BASE,
        iid: 1,
        project: project,
        title: 'Add an example of GoLang HTTP server',
        description: 'We should add an example of HTTP server written in GoLang.',
        assignees: [user]
      )
      FactoryBot.create(:epic_issue, epic: epic, issue: issue)
      FactoryBot.create(:merge_request,
        id: ID_BASE,
        iid: 1,
        source_project: project,
        author: user,
        assignees: [user],
        title: 'Add an example of GoLang HTTP server',
        description: 'This MR adds an example of HTTP server written in GoLang. Closes #1',
        target_branch: 'main',
        source_branch: 'feat-http-go')
      # Return the project for CI operations
      project
    end
    # Create CI resources in a separate transaction
    Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification
      .allow_cross_database_modification_within_transaction(
        url: 'gitlab-issue'
      ) do
      project = Project.find(ID_BASE)
      FactoryBot.create(:ci_empty_pipeline,
        status: :success,
        project: project,
        ref: 'main',
        sha: project.repository.commit.sha,
        partition_id: Ci::Pipeline.current_partition_value,
        user: user
      ).tap do |pipeline|
        pipeline.update_column(:id, ID_BASE)
        FactoryBot.create(:ci_stage, :success, pipeline: pipeline, name: 'test').tap do |stage|
          stage.update_column(:id, ID_BASE)
          FactoryBot.create(:ci_build, :success,
            pipeline: pipeline,
            ci_stage: stage,
            stage_idx: 1,
            project: project,
            user: user
          ).tap do |build|
            build.update_column(:id, ID_BASE)
            FactoryBot.create(:ci_job_artifact, :trace, job: build)
          end
        end
      end
    end
  end

  def create_git_bundle
    Dir.mktmpdir('git_bundle') do |dir|
      repo_path = "#{dir}/#{GROUP_PATH}/#{PROJECT_PATH}"
      repo_bundle_path = "#{repo_path}.bundle"

      system(*%W[#{Gitlab.config.git.bin_path} clone --mirror #{PROJECT_CLONE_URL} #{repo_path}])
      system(*%W[#{Gitlab.config.git.bin_path} -C #{repo_path} bundle create #{repo_bundle_path} --all])

      yield repo_bundle_path
    end
  end

  def clean!
    Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification
    .allow_cross_database_modification_within_transaction(
      url: 'gitlab-issue'
    ) do
      user = User.find_by_username('root')

      project = Project.find_by_full_path("#{GROUP_PATH}/#{PROJECT_PATH}")
      group = Group.find_by_path(GROUP_PATH)

      if project

        puts "Destroying #{GROUP_PATH}/#{PROJECT_PATH} project..."
        Sidekiq::Worker.skipping_transaction_check do
          Projects::DestroyService.new(project, user).execute
          project.send(:_run_after_commit_queue)
          project.repository.expire_all_method_caches
        end
      end

      if group
        puts "Destroying #{GROUP_PATH} group..."
        Sidekiq::Worker.skipping_transaction_check do
          Groups::DestroyService.new(group, user).execute
        end
      end

      # Synchronously execute LooseForeignKeys::CleanupWorker
      # to delete the records associated with the static ID.
      Gitlab::ExclusiveLease.skipping_transaction_check do
        LooseForeignKeys::CleanupWorker.new.perform
      end
    end
  end
end

FactoryBot::SyntaxRunner.class_eval do
  # FactoryBot doesn't allow yet to add a helper that can be used in factories
  # While the fixture_file_upload helper is reasonable to be used there:
  #
  # https://github.com/thoughtbot/factory_bot/issues/564#issuecomment-389491577
  def fixture_file_upload(*args, **kwargs)
    Rack::Test::UploadedFile.new(*args, **kwargs)
  end
end

Gitlab::Seeder.quiet do
  unless Gitlab::Utils.to_boolean(ENV['SEED_GITLAB_DUO'])
    puts "Skipped. Use the SEED_GITLAB_DUO=1 environment variable to enable."

    next
  end

  Gitlab::Seeder::GitLabDuo.new.clean!
  Gitlab::Seeder::GitLabDuo.new.seed!
end
