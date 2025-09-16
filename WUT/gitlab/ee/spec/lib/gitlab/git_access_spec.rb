# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitAccess, feature_category: :system_access do
  include EE::GeoHelpers
  include AdminModeHelper
  include NamespaceStorageHelpers
  include SessionHelpers

  let_it_be_with_reload(:user) { create(:user) }

  let(:actor) { user }
  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository }
  let(:repository_path) { "#{project.full_path}.git" }
  let(:protocol) { 'web' }
  let(:auth_result_type) { nil }
  let(:authentication_abilities) { %i[read_project download_code push_code] }
  let(:redirected_path) { nil }

  let(:access_class) do
    Class.new(described_class) do
      def push_ability
        :push_code
      end

      def download_ability
        :download_code
      end
    end
  end

  describe '#check_project_accessibility!' do
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:deploy_key) { create(:deploy_key, user: user) }
    let_it_be(:admin) { create(:admin) }

    let(:deploy_token) { create(:deploy_token, projects: [project]) }

    let(:start_sha) { '6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9' }
    let(:end_sha)   { '570e7b2abdd848b95f2f578043fc23bd6f6fd24d' }
    let(:changes)   { "#{start_sha} #{end_sha} refs/heads/master" }
    let(:push_error_message) { Gitlab::GitAccess::ERROR_MESSAGES[:upload] }

    before_all do
      project.add_developer(user)
      deploy_key.deploy_keys_projects.create!(project: project, can_push: true)
    end

    context 'with ip restriction' do
      before do
        allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
        stub_licensed_features(group_ip_restriction: true)
      end

      context 'group with restriction' do
        before do
          create(:ip_restriction, group: group, range: range)
        end

        context 'address is within the range' do
          let(:range) { '192.168.0.0/24' }

          context 'when actor is a DeployKey with access to project' do
            let(:actor) { deploy_key }

            it 'allows pull, push access' do
              aggregate_failures do
                expect { pull_changes }.not_to raise_error
                expect { push_changes }.not_to raise_error
              end
            end
          end

          context 'when actor is DeployToken with access to project' do
            let(:actor) { deploy_token }

            it 'allows pull access' do
              aggregate_failures do
                expect { pull_changes }.not_to raise_error
                expect { push_changes }.to raise_forbidden(push_error_message)
              end
            end
          end

          context 'when actor is user with access to project' do
            let(:actor) { user }

            it 'allows push, pull access' do
              aggregate_failures do
                expect { pull_changes }.not_to raise_error
                expect { push_changes }.not_to raise_error
              end
            end
          end

          context 'when actor is instance admin', :enable_admin_mode do
            let(:actor) { admin }

            it 'allows push, pull access' do
              aggregate_failures do
                expect { pull_changes }.not_to raise_error
                expect { push_changes }.not_to raise_error
              end
            end
          end
        end

        context 'address is outside the range' do
          let(:range) { '10.0.0.0/8' }

          context 'when actor is a DeployKey with access to project' do
            let(:actor) { deploy_key }

            it 'blocks pull, push with "not found"' do
              aggregate_failures do
                expect { pull_changes }.to raise_not_found
                expect { push_changes }.to raise_not_found
              end
            end
          end

          context 'when actor is DeployToken with access to project' do
            let(:actor) { deploy_token }

            it 'blocks pull, push with "not found"' do
              aggregate_failures do
                expect { pull_changes }.to raise_not_found
                expect { push_changes }.to raise_not_found
              end
            end
          end

          context 'when actor is user with access to project' do
            let(:actor) { user }

            it 'blocks pull, push with "not found"' do
              aggregate_failures do
                expect { pull_changes }.to raise_not_found
                expect { push_changes }.to raise_not_found
              end
            end
          end

          context 'when actor is instance admin', :enable_admin_mode do
            let(:actor) { admin }

            it 'allows push, pull access' do
              aggregate_failures do
                expect { pull_changes }.not_to raise_error
                expect { push_changes }.not_to raise_error
              end
            end
          end
        end
      end

      context 'group without restriction' do
        context 'when actor is a DeployKey with access to project' do
          let(:actor) { deploy_key }

          it 'allows pull, push access' do
            aggregate_failures do
              expect { pull_changes }.not_to raise_error
              expect { push_changes }.not_to raise_error
            end
          end
        end

        context 'when actor is DeployToken with access to project' do
          let(:actor) { deploy_token }

          it 'allows pull access' do
            aggregate_failures do
              expect { pull_changes }.not_to raise_error
              expect { push_changes }.to raise_forbidden(push_error_message)
            end
          end
        end

        context 'when actor is user with access to project' do
          let(:actor) { user }

          it 'allows push, pull access' do
            aggregate_failures do
              expect { pull_changes }.not_to raise_error
              expect { push_changes }.not_to raise_error
            end
          end
        end

        context 'when actor is instance admin', :enable_admin_mode do
          let(:actor) { admin }

          it 'allows push, pull access' do
            aggregate_failures do
              expect { pull_changes }.not_to raise_error
              expect { push_changes }.not_to raise_error
            end
          end
        end
      end
    end
  end

  context "when in a read-only GitLab instance" do
    before do
      create(:protected_branch, name: 'feature', project: project)
      allow(Gitlab::Database).to receive(:read_only?).and_return(true)
    end

    let(:primary_repo_url) { geo_primary_http_internal_url_to_repo(project) }
    let(:primary_repo_ssh_url) { geo_primary_ssh_url_to_repo(project) }

    context "with web access" do
      it_behaves_like 'git non-ssh access for a read-only GitLab instance'
    end
  end

  describe "push_rule_check" do
    let(:start_sha) { '6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9' }
    let(:end_sha)   { '570e7b2abdd848b95f2f578043fc23bd6f6fd24d' }
    let(:changes)   { "#{start_sha} #{end_sha} refs/heads/master" }

    before do
      project.add_developer(user)

      allow(project.repository).to receive(:new_commits)
        .and_return(project.repository.commits_between(start_sha, end_sha))
    end

    describe "author email check" do
      it 'returns true' do
        expect { push_changes(changes) }.not_to raise_error
      end

      it 'returns false when a commit message is missing required matches (positive regex match)' do
        project.create_push_rule(commit_message_regex: "@only.com")

        expect { push_changes(changes) }.to raise_error(described_class::ForbiddenError)
      end

      it 'returns false when a commit message contains forbidden characters (negative regex match)' do
        project.create_push_rule(commit_message_negative_regex: "@gmail.com")

        expect { push_changes(changes) }.to raise_error(described_class::ForbiddenError)
      end

      it 'returns true for tags' do
        project.create_push_rule(commit_message_regex: "@only.com")

        expect { push_changes("#{start_sha} #{end_sha} refs/tags/v1") }.not_to raise_error
      end

      it 'allows githook for new branch with an old bad commit' do
        bad_commit = double("Commit", safe_message: 'Some change', id: end_sha).as_null_object
        ref_object = double(name: 'heads/master')
        allow(bad_commit).to receive(:refs).and_return([ref_object])
        allow_next_instance_of(Repository) do |instance|
          allow(instance).to receive(:commits_between).and_return([bad_commit])
        end

        project.create_push_rule(commit_message_regex: "Change some files")

        # push to new branch, so use a blank old rev and new ref
        expect { push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{end_sha} refs/heads/new-branch") }.not_to raise_error
      end

      it 'allows githook for any change with an old bad commit' do
        bad_commit = double("Commit", safe_message: 'Some change', id: end_sha).as_null_object
        ref_object = double(name: 'heads/master')
        allow(bad_commit).to receive(:refs).and_return([ref_object])
        allow(project.repository).to receive(:commits_between).and_return([bad_commit])

        project.create_push_rule(commit_message_regex: "Change some files")

        # push to new branch, so use a blank old rev and new ref
        expect { push_changes("#{start_sha} #{end_sha} refs/heads/master") }.not_to raise_error
      end

      it 'does not allow any change from Web UI with bad commit' do
        bad_commit = double("Commit", safe_message: 'Some change', id: end_sha).as_null_object
        # We use tmp ref a a temporary for Web UI commiting
        ref_object = double(name: 'refs/tmp')
        allow(bad_commit).to receive(:refs).and_return([ref_object])
        allow(project.repository).to receive(:commits_between).and_return([bad_commit])
        allow(project.repository).to receive(:new_commits).and_return([bad_commit])

        project.create_push_rule(commit_message_regex: "Change some files")

        # push to new branch, so use a blank old rev and new ref
        expect { push_changes("#{start_sha} #{end_sha} refs/heads/master") }.to raise_error(described_class::ForbiddenError)
      end
    end

    describe "member_check" do
      let(:protocol) { 'http' }
      let(:changes) { "#{start_sha} #{end_sha} refs/heads/master" }

      before do
        project.create_push_rule(member_check: true)
      end

      it 'returns false for non-member user' do
        expect { push_changes(changes) }.to raise_error(described_class::ForbiddenError)
      end

      it 'returns true if committer is a gitlab member' do
        create(:user, email: 'dmitriy.zaporozhets@gmail.com')

        expect { push_changes(changes) }.not_to raise_error
      end
    end

    describe "file names check" do
      let(:start_sha) { '913c66a37b4a45b9769037c55c2d238bd0942d2e' }
      let(:end_sha) { '33f3729a45c02fc67d00adb1b8bca394b0e761d9' }
      let(:changes) { "#{start_sha} #{end_sha} refs/heads/master" }

      before do
        allow(project.repository).to receive(:new_commits)
          .and_return(project.repository.commits_between(start_sha, end_sha))
      end

      it 'returns false when filename is prohibited' do
        project.create_push_rule(file_name_regex: "jpg$")

        expect { push_changes(changes) }.to raise_error(described_class::ForbiddenError)
      end

      it 'returns true if file name is allowed' do
        project.create_push_rule(file_name_regex: "exe$")

        expect { push_changes(changes) }.not_to raise_error
      end
    end

    describe "max file size check" do
      let(:start_sha) { ::Gitlab::Git::SHA1_BLANK_SHA }
      # SHA of the 2-mb-file branch
      let(:end_sha)   { 'bf12d2567099e26f59692896f73ac819bae45b00' }
      let(:changes) { "#{start_sha} #{end_sha} refs/heads/my-branch" }

      before do
        project.add_developer(user)
        # Delete branch so Repository#new_blobs can return results
        repository.delete_branch('2-mb-file')
      end

      it "returns false when size is too large" do
        project.create_push_rule(max_file_size: 1)

        expect(repository.new_blobs(end_sha)).to be_present
        expect { push_changes(changes) }.to raise_error(described_class::ForbiddenError)
      end

      it "returns true when size is allowed" do
        project.create_push_rule(max_file_size: 3)

        expect(repository.new_blobs(end_sha)).to be_present
        expect { push_changes(changes) }.not_to raise_error
      end
    end
  end

  context 'when namespace storage size is below the limit', :saas do
    let(:sha_with_smallest_changes) { 'b9238ee5bf1d7359dd3b8c89fd76c1c7f8b75aba' }
    let(:namespace) { create(:group_with_plan, :private, plan: :free_plan) }

    before do
      project.add_developer(user)
      project.update!(namespace: namespace)
      stub_ee_application_setting(dashboard_limit_enabled: true)
    end

    it 'rejects the push' do
      expect { push_changes }.to raise_error(described_class::ForbiddenError, /Your top-level group is over the user limit/)
    end
  end

  describe 'repository size restrictions' do
    # SHA for the 2-mb-file branch
    let(:sha_with_2_mb_file) { 'bf12d2567099e26f59692896f73ac819bae45b00' }
    # SHA for the wip branch
    let(:sha_with_smallest_changes) { 'b9238ee5bf1d7359dd3b8c89fd76c1c7f8b75aba' }

    before do
      project.add_developer(user)
      # Delete branch so Repository#new_blobs can return results
      repository.delete_branch('2-mb-file')
      repository.delete_branch('wip')

      project.update_attribute(:repository_size_limit, repository_size_limit)
      project.statistics.update!(repository_size: repository_size)
    end

    shared_examples_for 'a push to repository over the limit' do
      it 'rejects the push' do
        expect do
          push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_smallest_changes} refs/heads/master")
        end.to raise_error(described_class::ForbiddenError, /Your push to this repository cannot be completed because this repository has exceeded the allocated storage for your project. Contact your GitLab administrator for more information./)
      end

      context 'when deleting a branch' do
        it 'accepts the operation' do
          expect do
            push_changes("#{sha_with_smallest_changes} #{::Gitlab::Git::SHA1_BLANK_SHA} refs/heads/feature")
          end.not_to raise_error
        end
      end
    end

    shared_examples_for 'a push to repository below the limit' do
      context 'when trying to authenticate the user' do
        it 'does not raise an error' do
          expect { push_changes }.not_to raise_error
        end
      end

      context 'when pushing a new branch' do
        before do
          lfs_integrity = instance_double(Gitlab::Checks::LfsIntegrity)
          allow(Gitlab::Checks::LfsIntegrity).to receive(:new).and_return(lfs_integrity)
          allow(lfs_integrity).to receive(:objects_missing?).and_return(false)
        end

        it 'accepts the push' do
          master_sha = project.commit('master').id

          expect do
            push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{master_sha} refs/heads/my_branch")
          end.not_to raise_error
        end
      end
    end

    context 'when GIT_OBJECT_DIRECTORY_RELATIVE env var is set', :request_store do
      before do
        ::Gitlab::Git::HookEnv.set(project.repository.gl_repository,
          project.repository.raw_repository.relative_path,
          "GIT_OBJECT_DIRECTORY_RELATIVE" => "objects")

        # Stub the object directory size to "simulate" quarantine size
        allow(repository)
          .to receive(:object_directory_size)
          .and_return(object_directory_size)
      end

      let(:object_directory_size) { 1.megabyte }

      context 'when repository size is over limit' do
        let(:repository_size) { 2.megabytes }
        let(:repository_size_limit) { 1.megabyte }

        it_behaves_like 'a push to repository over the limit'

        context 'when namespace storage size is below the limit', :saas do
          let(:namespace) { create(:group_with_plan, :with_root_storage_statistics, plan: :ultimate_plan) }

          before do
            set_enforcement_limit(namespace, megabytes: 100)
            set_used_storage(namespace, megabytes: 20)
          end

          it_behaves_like 'a push to repository over the limit'
        end
      end

      context 'when repository size is below the limit' do
        let(:repository_size) { 1.megabyte }
        let(:repository_size_limit) { 2.megabytes }

        before do
          lfs_integrity = instance_double(Gitlab::Checks::LfsIntegrity)
          allow(Gitlab::Checks::LfsIntegrity).to receive(:new).and_return(lfs_integrity)
          allow(lfs_integrity).to receive(:objects_missing?).and_return(false)
        end

        it_behaves_like 'a push to repository below the limit'

        context 'when object directory (quarantine) size exceeds the limit' do
          let(:object_directory_size) { 2.megabytes }

          it 'rejects the push' do
            expect do
              push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")
            end.to raise_error(described_class::ForbiddenError, /Your push to this repository cannot be completed as it would exceed the allocated storage for your project. Contact your GitLab administrator for more information./)
          end
        end

        context 'when object directory (quarantine) size does not exceed the limit' do
          it 'accepts the push' do
            expect do
              push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_smallest_changes} refs/heads/my_branch_3")
            end.not_to raise_error
          end
        end

        context 'when namespace storage size is over the limit', :saas do
          let(:namespace) { create(:group_with_plan, :with_root_storage_statistics, plan: :ultimate_plan) }

          before do
            set_enforcement_limit(namespace, megabytes: 100)
            set_used_storage(namespace, megabytes: 101)
          end

          it_behaves_like 'a push to repository below the limit'
        end
      end
    end

    context 'when GIT_OBJECT_DIRECTORY_RELATIVE env var is not set and git-rev-list is used for checking against the repository size limit' do
      context 'when repository size is over limit' do
        let(:repository_size) { 2.megabytes }
        let(:repository_size_limit) { 1.megabyte }

        it_behaves_like 'a push to repository over the limit'

        context 'when namespace storage size is below the limit', :saas do
          let(:namespace) { create(:group_with_plan, :with_root_storage_statistics, plan: :ultimate_plan) }

          before do
            set_enforcement_limit(namespace, megabytes: 100)
            set_used_storage(namespace, megabytes: 20)
          end

          it_behaves_like 'a push to repository over the limit'
        end
      end

      context 'when repository size is below the limit' do
        let(:repository_size) { 1.megabyte }
        let(:repository_size_limit) { 2.megabytes }

        it_behaves_like 'a push to repository below the limit'

        context 'when new change exceeds the limit' do
          it 'rejects the push' do
            expect(repository.new_blobs(sha_with_2_mb_file)).to be_present

            expect do
              push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")
            end.to raise_error(described_class::ForbiddenError, /Your push to this repository cannot be completed as it would exceed the allocated storage for your project. Contact your GitLab administrator for more information./)
          end
        end

        context 'when new change does not exceed the limit' do
          it 'accepts the push' do
            expect(repository.new_blobs(sha_with_smallest_changes)).to be_present

            expect do
              push_changes("#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_smallest_changes} refs/heads/my_branch_3")
            end.not_to raise_error
          end
        end

        context 'when namespace storage size is over the limit', :saas do
          let(:namespace) { create(:group_with_plan, :with_root_storage_statistics, plan: :ultimate_plan) }

          before do
            set_enforcement_limit(namespace, megabytes: 100)
            set_used_storage(namespace, megabytes: 101)
          end

          it_behaves_like 'a push to repository below the limit'
        end
      end
    end
  end

  describe 'Geo' do
    let_it_be(:primary_node) { create(:geo_node, :primary) }
    let_it_be(:secondary_node) { create(:geo_node) }

    context 'git pull' do
      let(:actor) { :geo }

      it { expect { pull_changes }.not_to raise_error }

      context 'for non-Geo with maintenance mode' do
        before do
          stub_maintenance_mode_setting(true)
        end

        it 'does not return a replication lag message nor call the lag check' do
          allow_next_instance_of(Gitlab::Geo::HealthCheck) do |instance|
            expect(instance).not_to receive(:db_replication_lag_seconds)
          end

          expect(pull_changes.console_messages).to be_empty
        end
      end

      context 'for a primary' do
        before do
          stub_licensed_features(geo: true)
          stub_current_geo_node(primary_node)
        end

        context 'when the request is signed by a Geo site' do
          let(:actor) { :geo }

          it { expect { pull_changes }.not_to raise_error }
        end

        # This case should be fully tested elsewhere. It's only here as a point of comparison with :geo actor.
        context 'when the actor is a user and the user is a developer' do
          let(:actor) { user }

          before do
            project.add_developer(user)
          end

          it { expect { pull_changes }.not_to raise_error }
        end

        # This case should be fully tested elsewhere. It's only here as a point of comparison with :geo actor.
        context 'when the actor is a key' do
          let_it_be(:deploy_key) { create(:deploy_key, user: user) }
          let(:actor) { deploy_key }

          before do
            project.add_developer(user)
            deploy_key.deploy_keys_projects.create!(project: project)
          end

          it { expect { pull_changes }.not_to raise_error }
        end

        context 'when Git over HTTP protocol is disabled and the request is signed by a Geo site' do
          let(:actor) { :geo }
          let(:protocol) { 'http' }
          let(:enabled_protocol) { 'ssh' }

          before do
            stub_application_setting(enabled_git_access_protocol: enabled_protocol)
          end

          it { expect { pull_changes }.not_to raise_error }
        end
      end
    end

    context 'git push' do
      context 'for a primary' do
        before do
          stub_licensed_features(geo: true)
          stub_current_geo_node(primary_node)
        end

        context 'when the request is signed by a Geo site' do
          let(:actor) { :geo }

          it { expect { push_changes }.to raise_forbidden(Gitlab::GitAccess::ERROR_MESSAGES[:upload]) }
        end

        # This case should be fully tested elsewhere. It's only here as a point of comparison with :geo actor.
        context 'when the actor is a user and the user is a developer' do
          let(:actor) { user }

          before do
            project.add_developer(user)
          end

          it { expect { push_changes }.not_to raise_error }
        end

        # This case should be fully tested elsewhere. It's only here as a point of comparison with :geo actor.
        context 'when the actor is a key' do
          let_it_be(:deploy_key) { create(:deploy_key, user: user) }
          let(:actor) { deploy_key }

          before do
            project.add_developer(user)
            deploy_key.deploy_keys_projects.create!(project: project, can_push: true)
          end

          it { expect { push_changes }.not_to raise_error }
        end
      end
      # secondary cases moved to geo_git_access_spec.rb
    end
  end

  describe '#check_push_access!' do
    let(:protocol) { 'ssh' }
    let(:unprotected_branch) { 'unprotected_branch' }

    before do
      merge_into_protected_branch
    end

    let(:start_sha) { '6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9' }
    let(:end_sha)   { '570e7b2abdd848b95f2f578043fc23bd6f6fd24d' }

    let(:changes) do
      { any: Gitlab::GitAccess::ANY,
        push_new_branch: "#{Gitlab::Git::SHA1_BLANK_SHA} #{end_sha} refs/heads/wow",
        push_master: "#{start_sha} #{end_sha} refs/heads/master",
        push_protected_branch: "#{start_sha} #{end_sha} refs/heads/feature",
        push_remove_protected_branch: "#{end_sha} #{Gitlab::Git::SHA1_BLANK_SHA} "\
                                      "refs/heads/feature",
        push_tag: "#{start_sha} #{end_sha} refs/tags/v1.0.0",
        push_new_tag: "#{Gitlab::Git::SHA1_BLANK_SHA} #{end_sha} refs/tags/v7.8.9",
        push_all: ["#{start_sha} #{end_sha} refs/heads/master", "#{start_sha} #{end_sha} refs/heads/feature"],
        merge_into_protected_branch: "0b4bc9a #{merge_into_protected_branch} refs/heads/feature" }
    end

    def merge_into_protected_branch
      @protected_branch_merge_commit ||= begin
        project.repository.add_branch(user, unprotected_branch, 'feature')
        target_branch = TestEnv::BRANCH_SHA['feature']
        source_branch = project.repository.create_file(
          user,
          'filename',
          'This is the file content',
          message: 'This is a good commit message',
          branch_name: unprotected_branch)
        merge_id = project.repository.raw.merge_to_ref(
          user,
          branch: target_branch,
          first_parent_ref: target_branch,
          source_sha: source_branch,
          target_ref: 'refs/merge-requests/test',
          message: 'commit message'
        )

        # We are trying to simulate what the repository would look like
        # during the pre-receive hook, before the actual ref is
        # written/created. Repository#new_commits relies on there being no
        # ref pointing to the merge commit.
        project.repository.delete_refs('refs/merge-requests/test')

        merge_id
      end
    end

    def self.run_permission_checks(permissions_matrix)
      permissions_matrix.each_pair do |role, matrix|
        # Run through the entire matrix for this role in one test to avoid
        # repeated setup.
        #
        # Expectations are given a custom failure message proc so that it's
        # easier to identify which check(s) failed.
        it "has the correct permissions for #{role}s" do
          if [:admin_with_admin_mode, :admin_without_admin_mode].include?(role)
            user.update_attribute(:admin, true)
            enable_admin_mode!(user) if role == :admin_with_admin_mode
            project.add_guest(user)
          else
            project.add_role(user, role)
          end

          protected_branch.save!

          aggregate_failures do
            matrix.each do |action, allowed|
              check = -> { push_changes(changes[action]) }

              if allowed
                expect(&check).not_to raise_error,
                  -> { "expected #{action} to be allowed" }
              else
                expect(&check).to raise_error(Gitlab::GitAccess::ForbiddenError),
                  -> { "expected #{action} to be disallowed" }
              end
            end
          end
        end
      end
    end

    # Run permission checks for a group
    def self.run_group_permission_checks(permissions_matrix)
      permissions_matrix.each_pair do |role, matrix|
        it "has the correct permissions for group #{role}s" do
          create(:project_group_link, role, group: group, project: project)

          protected_branch.save!(validate: false)

          aggregate_failures do
            matrix.each do |action, allowed|
              check = -> { push_changes(changes[action]) }

              if allowed
                expect(&check).not_to raise_error,
                  -> { "expected #{action} to be allowed" }
              else
                expect(&check).to raise_error(Gitlab::GitAccess::ForbiddenError),
                  -> { "expected #{action} to be disallowed" }
              end
            end
          end
        end
      end
    end

    permissions_matrix = {
      admin_with_admin_mode: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      admin_without_admin_mode: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      maintainer: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      developer: {
        any: true,
        push_new_branch: true,
        push_master: true,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: false,
        merge_into_protected_branch: false
      },

      reporter: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      guest: {
        any: false,
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      }
    }

    [%w[feature exact], ['feat*', 'wildcard']].each do |protected_branch_name, protected_branch_type|
      context "user-specific access control" do
        let(:user) { create(:user) }

        context "when a specific user is allowed to push into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_user_to_push: user, name: protected_branch_name, project: project) }

          run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
            guest: { push_protected_branch: false, merge_into_protected_branch: false },
            reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end

        context "when a specific user is allowed to merge into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_user_to_merge: user, name: protected_branch_name, project: project) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
          end

          run_permission_checks(permissions_matrix.deep_merge(admin_with_admin_mode: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
            admin_without_admin_mode: { push_protected_branch: false, merge_into_protected_branch: false },
            maintainer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
            developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
            guest: { push_protected_branch: false, merge_into_protected_branch: false },
            reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end

        context "when a specific user is allowed to push & merge into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_user_to_push: user, authorize_user_to_merge: user, name: protected_branch_name, project: project) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
          end

          run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
            guest: { push_protected_branch: false, merge_into_protected_branch: false },
            reporter: { push_protected_branch: false, merge_into_protected_branch: false }))
        end
      end

      context "when license blocks changes", :without_license do
        let(:actor) { create(:admin) }

        before do
          create_current_license(starts_at: 1.month.ago.to_date, block_changes_at: Date.current, notify_admins_at: Date.current)
          enable_admin_mode!(actor)
          project.add_role(actor, :developer)
        end

        it 'raises an error' do
          expect { push_changes(changes[:any]) }.to raise_error(Gitlab::GitAccess::ForbiddenError, /If you don't renew by/)
        end
      end

      context "group-specific access control" do
        let(:user) { create(:user) }
        let(:group) { create(:group) }

        before do
          group.add_maintainer(user)
        end

        context "when a specific group is allowed to push into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_group_to_push: group, name: protected_branch_name, project: project) }

          permissions = permissions_matrix.except(:admin_with_admin_mode, :admin_without_admin_mode)
                            .deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                              reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end

        context "when a specific group is allowed to merge into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_group_to_merge: group, name: protected_branch_name, project: project) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
          end

          permissions = permissions_matrix.except(:admin_with_admin_mode, :admin_without_admin_mode)
                            .deep_merge(maintainer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                              developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: true },
                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                              reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end

        context "when a specific group is allowed to push & merge into the #{protected_branch_type} protected branch" do
          let(:protected_branch) { build(:protected_branch, authorize_group_to_push: group, authorize_group_to_merge: group, name: protected_branch_name, project: project) }

          before do
            create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
          end

          permissions = permissions_matrix.except(:admin_with_admin_mode, :admin_without_admin_mode)
                            .deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true },
                              guest: { push_protected_branch: false, merge_into_protected_branch: false },
                              reporter: { push_protected_branch: false, merge_into_protected_branch: false })

          run_group_permission_checks(permissions)
        end
      end
    end
  end

  describe '#check_smartcard_access!' do
    before do
      stub_licensed_features(smartcard_auth: true)
      stub_smartcard_setting(enabled: true, required_for_git_access: true)

      project.add_developer(user)
    end

    context 'user with a smartcard session', :clean_gitlab_redis_sessions do
      let(:session_id) { '42' }
      let(:stored_session) do
        { 'smartcard_signins' => { 'last_signin_at' => 5.minutes.ago } }
      end

      before do
        Gitlab::Redis::Sessions.with do |redis|
          redis.set("session:gitlab:#{session_id}", Marshal.dump(stored_session))
          redis.sadd("session:lookup:user:gitlab:#{user.id}", [session_id])
        end
      end

      it 'allows pull changes' do
        expect { pull_changes }.not_to raise_error
      end

      it 'allows push changes' do
        expect { push_changes }.not_to raise_error
      end
    end

    context 'user without a smartcard session' do
      it 'does not allow pull changes' do
        expect { pull_changes }.to raise_error(Gitlab::GitAccess::ForbiddenError)
      end

      it 'does not allow push changes' do
        expect { push_changes }.to raise_error(Gitlab::GitAccess::ForbiddenError)
      end
    end

    context 'with the setting off' do
      before do
        stub_smartcard_setting(required_for_git_access: false)
      end

      it 'allows pull changes' do
        expect { pull_changes }.not_to raise_error
      end

      it 'allows push changes' do
        expect { push_changes }.not_to raise_error
      end
    end
  end

  describe '#check_otp_session!' do
    let_it_be(:user) { create(:user, :two_factor_via_otp) }
    let_it_be(:key) { create(:key, user: user) }
    let_it_be(:actor) { key }

    let(:protocol) { 'ssh' }

    before do
      project.add_developer(user)
      stub_feature_flags(two_factor_for_cli: true)
      stub_licensed_features(git_two_factor_enforcement: true)
    end

    context 'with an OTP session', :clean_gitlab_redis_sessions do
      before do
        Gitlab::Redis::Sessions.with do |redis|
          redis.set("#{Gitlab::Redis::Sessions::OTP_SESSIONS_NAMESPACE}:#{key.id}", true)
        end
      end

      it 'allows push and pull access' do
        aggregate_failures do
          expect { push_changes }.not_to raise_error
          expect { pull_changes }.not_to raise_error
        end
      end

      context 'based on the duration set by the `git_two_factor_session_expiry` setting' do
        let_it_be(:git_two_factor_session_expiry) { 20 }
        let_it_be(:redis_key_expiry_at) { git_two_factor_session_expiry.minutes.from_now }

        before do
          stub_application_setting(git_two_factor_session_expiry: git_two_factor_session_expiry)
        end

        def value_of_key
          key_expired = redis_key_expiry_at.past?
          return if key_expired

          true
        end

        def stub_redis
          redis = double(:redis)
          expect(Gitlab::Redis::Sessions).to receive(:with).at_most(:twice).and_yield(redis)

          expect(redis).to(
            receive(:get)
              .with("#{Gitlab::Redis::Sessions::OTP_SESSIONS_NAMESPACE}:#{key.id}"))
                       .at_most(:twice)
                       .and_return(value_of_key)
        end

        context 'at a time before the stipulated expiry' do
          it 'allows push and pull access' do
            travel_to(10.minutes.from_now) do
              stub_redis

              aggregate_failures do
                expect { push_changes }.not_to raise_error
                expect { pull_changes }.not_to raise_error
              end
            end
          end
        end

        context 'at a time after the stipulated expiry' do
          it 'does not allow push and pull access' do
            travel_to(30.minutes.from_now) do
              stub_redis

              aggregate_failures do
                expect { push_changes }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
                expect { pull_changes }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
              end
            end
          end
        end
      end
    end

    context 'without OTP session' do
      it 'does not allow push or pull access' do
        user = 'jane.doe'
        host = 'fridge.ssh'
        port = 42

        stub_config(
          gitlab_shell: {
            ssh_user: user,
            ssh_host: host,
            ssh_port: port
          }
        )

        error_message = "OTP verification is required to access the repository.\n\n   "\
                        "Use: ssh #{user}@#{host} -p #{port} 2fa_verify"

        aggregate_failures do
          expect { push_changes }.to raise_forbidden(error_message)
          expect { pull_changes }.to raise_forbidden(error_message)
        end
      end

      context 'when protocol is HTTP' do
        let(:protocol) { 'http' }

        it 'allows push and pull access' do
          aggregate_failures do
            expect { push_changes }.not_to raise_error
            expect { pull_changes }.not_to raise_error
          end
        end
      end

      context 'when actor is not an SSH key' do
        let(:deploy_key) { create(:deploy_key, user: user) }
        let(:actor) { deploy_key }

        before do
          deploy_key.deploy_keys_projects.create!(project: project, can_push: true)
        end

        it 'allows push and pull access' do
          aggregate_failures do
            expect { push_changes }.not_to raise_error
            expect { pull_changes }.not_to raise_error
          end
        end
      end

      context 'when 2FA is not enabled for the user' do
        let(:user) { create(:user) }
        let(:actor) { create(:key, user: user) }

        it 'allows push and pull access' do
          aggregate_failures do
            expect { push_changes }.not_to raise_error
            expect { pull_changes }.not_to raise_error
          end
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(two_factor_for_cli: false)
        end

        it 'allows push and pull access' do
          aggregate_failures do
            expect { push_changes }.not_to raise_error
            expect { pull_changes }.not_to raise_error
          end
        end
      end

      context 'when licensed feature is not available' do
        before do
          stub_licensed_features(git_two_factor_enforcement: false)
        end

        it 'allows push and pull access' do
          aggregate_failures do
            expect { push_changes }.not_to raise_error
            expect { pull_changes }.not_to raise_error
          end
        end
      end
    end
  end

  describe '#check_sso_session!', :clean_gitlab_redis_sessions do
    let_it_be_with_reload(:root_group) { create(:group) }
    let_it_be_with_reload(:subgroup) { create(:group, parent: root_group) }

    let_it_be_with_reload(:saml_provider) { create(:saml_provider, enforced_sso: true, group: root_group) }
    let_it_be(:identity) { create(:group_saml_identity, saml_provider: saml_provider, user: user) }

    def sso_session_data
      { 'active_group_sso_sign_ins' => { saml_provider.id => 5.minutes.ago } }
    end

    before do
      stub_licensed_features(group_saml: true)
      project.add_developer(user)
    end

    shared_examples 'Git access allowed' do
      it 'allows push and pull changes' do
        aggregate_failures do
          expect { pull_changes }.not_to raise_error
          expect { push_changes }.not_to raise_error
        end
      end
    end

    shared_examples 'Git access not allowed' do
      it 'does not allow push and pull changes' do
        aggregate_failures do
          address = "http://localhost/groups/#{root_group.name}/-/saml/sso?token="

          expect { pull_changes }.to raise_error(Gitlab::GitAccess::ForbiddenError, /#{Regexp.quote(address)}/)
          expect { push_changes }.to raise_error(Gitlab::GitAccess::ForbiddenError, /#{Regexp.quote(address)}/)
        end
      end
    end

    context 'when Git is accessed by a user' do
      using RSpec::Parameterized::TableSyntax

      where(:project_namespace, :git_check_enforced?, :owner_of_project_namespace?, :owner_of_root_group?, :active_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
        # Project without a namespace
        nil              | nil   | nil   | nil   | nil   | nil   | nil   | nil   | 'Git access allowed'

        # Project with a namespace
        ref(:root_group) | false | nil   | nil   | nil   | nil   | nil   | nil   | 'Git access allowed'
        ref(:root_group) | true  | false | nil   | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:root_group) | true  | true  | nil   | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:root_group) | true  | false | nil   | true  | nil   | nil   | nil   | 'Git access allowed'

        ref(:subgroup)   | false | nil   | nil   | nil   | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | true  | false | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | true  | false | true  | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | true  | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | false | true  | true  | nil   | nil   | nil   | 'Git access allowed'

        # Auditor user
        ref(:root_group) | true  | false | nil   | false | nil   | nil   | true  | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | false | nil   | nil   | true  | 'Git access allowed'

        # Admin user
        ref(:root_group) | true  | false | nil   | false | true  | false | nil   | 'Git access not allowed'
        ref(:root_group) | true  | false | nil   | true  | true  | false | nil   | 'Git access allowed'
        ref(:root_group) | true  | false | nil   | false | true  | true  | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | false | true  | false | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | false | false | true  | true  | false | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | false | true  | true  | nil   | 'Git access allowed'
      end

      with_them do
        before do
          stub_session(session_data: sso_session_data, user_id: user.id) if active_session?
          user.update!(admin: true) if user_is_admin?
          user.update!(auditor: true) if user_is_auditor?

          if project_namespace
            project.update!(namespace: project_namespace)
            saml_provider.update!(git_check_enforced: git_check_enforced?)

            project_namespace.add_owner(user) if owner_of_project_namespace?
            root_group.add_owner(user) if owner_of_root_group?
          end
        end

        context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
          it_behaves_like params[:shared_examples]
        end
      end
    end

    context 'when SSO is enforced and Git is accessed by another actor' do
      before do
        project.update!(namespace: root_group)
        saml_provider.update!(git_check_enforced: true)
      end

      context 'when the request is made from CI builds' do
        let(:protocol) { 'http' }
        let(:auth_result_type) { :build }

        it_behaves_like 'Git access allowed'

        context 'when legacy CI credentials are used' do
          let(:auth_result_type) { :ci }

          it_behaves_like 'Git access allowed'
        end
      end
    end
  end

  describe '#check_maintenance_mode!' do
    let(:changes) { Gitlab::GitAccess::ANY }

    before do
      project.add_maintainer(user)
    end

    def push_access_check
      access.check('git-receive-pack', changes)
    end

    context 'when maintenance mode is enabled' do
      before do
        stub_maintenance_mode_setting(true)
      end

      it 'blocks git push' do
        aggregate_failures do
          expect { push_access_check }.to raise_forbidden('Git push is not allowed because this GitLab instance is currently in (read-only) maintenance mode.')
        end
      end
    end

    context 'when maintenance mode is disabled' do
      before do
        stub_maintenance_mode_setting(false)
      end

      it 'allows git push' do
        expect { push_access_check }.not_to raise_error
      end
    end
  end

  describe '#check_valid_actor!' do
    context 'key expiration is enforced' do
      let(:actor) { build(:key, expires_at: 2.days.ago) }

      it 'does not allow expired keys', :aggregate_failures do
        expect { push_changes }.to raise_forbidden('Your SSH key has expired.')
        expect { pull_changes }.to raise_forbidden('Your SSH key has expired.')
      end
    end
  end

  describe '#check_download_access!' do
    let(:actor) { user }

    before do
      project.add_developer(user)
    end

    it 'disallows hidden projects to be to pulled' do
      project.update!(hidden: true)

      expect { pull_changes }.to raise_forbidden(described_class::ERROR_MESSAGES[:download])
    end
  end

  private

  def access
    access_class.new(
      actor,
      project,
      protocol,
      authentication_abilities: authentication_abilities,
      repository_path: repository_path,
      redirected_path: redirected_path,
      auth_result_type: auth_result_type
    )
  end

  def push_changes(changes = '_any')
    access.check('git-receive-pack', changes)
  end

  def pull_changes(changes = '_any')
    access.check('git-upload-pack', changes)
  end

  def raise_forbidden(message)
    raise_error(Gitlab::GitAccess::ForbiddenError, message)
  end

  def raise_not_found
    raise_error(Gitlab::GitAccess::NotFoundError, Gitlab::GitAccess::ERROR_MESSAGES[:project_not_found])
  end
end
