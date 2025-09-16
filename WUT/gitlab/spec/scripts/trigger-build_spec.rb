# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles

require 'fast_spec_helper'
require 'rspec-parameterized'

require 'gitlab/error'
require 'gitlab/objectified_hash'

require_relative '../../scripts/trigger-build'

RSpec.describe Trigger, feature_category: :tooling do
  let(:env) do
    {
      'CI_JOB_URL' => 'ci_job_url',
      'CI_PROJECT_PATH' => 'ci_project_path',
      'CI_COMMIT_REF_NAME' => 'ci_commit_ref_name',
      'CI_COMMIT_REF_SLUG' => 'ci_commit_ref_slug',
      'CI_COMMIT_SHA' => 'ci_commit_sha',
      'CI_MERGE_REQUEST_PROJECT_ID' => 'ci_merge_request_project_id',
      'CI_MERGE_REQUEST_IID' => 'ci_merge_request_iid',
      'CI_MERGE_REQUEST_TARGET_BRANCH_NAME' => 'master',
      'PROJECT_TOKEN_FOR_CI_SCRIPTS_API_USAGE' => 'bot-token',
      'CI_JOB_TOKEN' => 'job-token',
      'GITLAB_USER_NAME' => 'gitlab_user_name',
      'GITLAB_USER_LOGIN' => 'gitlab_user_login',
      'QA_IMAGE' => 'qa_image',
      'DOCS_PROJECT_API_TOKEN' => nil
    }
  end

  let(:com_api_endpoint) { Trigger::Base.new.send(:endpoint) }
  let(:com_api_token) { env['PROJECT_TOKEN_FOR_CI_SCRIPTS_API_USAGE'] }
  let(:com_gitlab_client) { double('com_gitlab_client') }

  let(:downstream_gitlab_client_endpoint) { com_api_endpoint }
  let(:downstream_gitlab_client_token) { com_api_token }
  let(:downstream_gitlab_client) { com_gitlab_client }

  let(:stubbed_pipeline) { Struct.new(:id, :web_url).new(42, 'pipeline_url') }
  let(:trigger_token) { env['CI_JOB_TOKEN'] }

  before do
    stub_env(env)
    allow(subject).to receive(:puts)
    allow(Gitlab).to receive(:client)
      .with(
        endpoint: downstream_gitlab_client_endpoint,
        private_token: downstream_gitlab_client_token
      )
      .and_return(downstream_gitlab_client)
  end

  def expect_run_trigger_with_params(variables = {})
    expect(downstream_gitlab_client).to receive(:run_trigger)
      .with(
        downstream_project_path,
        trigger_token,
        ref,
        hash_including(variables)
      )
      .and_return(stubbed_pipeline)
  end

  describe Trigger::Base do
    let(:ref) { 'main' }

    describe '#invoke!' do
      context "when required methods aren't defined" do
        it 'raises a NotImplementedError' do
          expect { described_class.new.invoke! }.to raise_error(NotImplementedError)
        end
      end

      context "when required methods are defined" do
        let(:downstream_project_path) { 'foo/bar' }
        let(:subclass) do
          Class.new(Trigger::Base) do
            def downstream_project_path
              'foo/bar'
            end

            # Must be overridden
            def ref_param_name
              'FOO_BAR_BRANCH'
            end
          end
        end

        subject { subclass.new }

        context 'when env variable `FOO_BAR_BRANCH` does not exist' do
          it 'triggers the pipeline on the correct project and branch' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end

        context 'when env variable `FOO_BAR_BRANCH` exists' do
          let(:ref) { 'foo_bar_branch' }

          before do
            stub_env('FOO_BAR_BRANCH', ref)
          end

          it 'triggers the pipeline on the correct project and branch' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end

        it 'waits for downstream pipeline' do
          expect_run_trigger_with_params
          expect(Trigger::Pipeline).to receive(:new)
            .with(downstream_project_path, stubbed_pipeline.id, downstream_gitlab_client)

          subject.invoke!
        end
      end
    end

    describe '#variables' do
      let(:simple_forwarded_variables) do
        {
          'TRIGGER_SOURCE' => env['CI_JOB_URL'],
          'TOP_UPSTREAM_SOURCE_PROJECT' => env['CI_PROJECT_PATH'],
          'TOP_UPSTREAM_SOURCE_REF' => env['CI_COMMIT_REF_NAME'],
          'TOP_UPSTREAM_SOURCE_JOB' => env['CI_JOB_URL'],
          'TOP_UPSTREAM_MERGE_REQUEST_PROJECT_ID' => env['CI_MERGE_REQUEST_PROJECT_ID'],
          'TOP_UPSTREAM_MERGE_REQUEST_IID' => env['CI_MERGE_REQUEST_IID']
        }
      end

      it 'includes simple forwarded variables' do
        expect(subject.variables).to include(simple_forwarded_variables)
      end

      describe "#base_variables" do
        context 'when CI_COMMIT_TAG is set' do
          before do
            stub_env('CI_COMMIT_TAG', 'v1.0')
          end

          it 'sets GITLAB_REF_SLUG to CI_COMMIT_REF_NAME' do
            expect(subject.variables['GITLAB_REF_SLUG']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end

        context 'when CI_COMMIT_TAG is nil' do
          before do
            stub_env('CI_COMMIT_TAG', nil)
          end

          it 'sets GITLAB_REF_SLUG to CI_COMMIT_REF_SLUG' do
            expect(subject.variables['GITLAB_REF_SLUG']).to eq(env['CI_COMMIT_REF_SLUG'])
          end
        end

        context 'when TRIGGERED_USER is set' do
          before do
            stub_env('TRIGGERED_USER', 'triggered_user')
          end

          it 'sets TRIGGERED_USER to triggered_user' do
            expect(subject.variables['TRIGGERED_USER']).to eq('triggered_user')
          end
        end

        context 'when TRIGGERED_USER is not set' do
          before do
            stub_env('TRIGGERED_USER', nil)
          end

          it 'sets TRIGGERED_USER to GITLAB_USER_NAME' do
            expect(subject.variables['TRIGGERED_USER']).to eq(env['GITLAB_USER_NAME'])
          end
        end

        context 'when CI_COMMIT_SHA is set' do
          before do
            stub_env('CI_COMMIT_SHA', 'ci_commit_sha')
          end

          it 'sets TOP_UPSTREAM_SOURCE_SHA to CI_COMMIT_SHA' do
            expect(subject.variables['TOP_UPSTREAM_SOURCE_SHA']).to eq('ci_commit_sha')
          end
        end
      end

      describe "#version_file_variables" do
        using RSpec::Parameterized::TableSyntax

        where(:version_file, :version) do
          'GITALY_SERVER_VERSION'                | "1"
          'GITLAB_ELASTICSEARCH_INDEXER_VERSION' | "2"
          'GITLAB_KAS_VERSION'                   | "3"
          'GITLAB_PAGES_VERSION'                 | "4"
          'GITLAB_SHELL_VERSION'                 | "5"
          'GITLAB_WORKHORSE_VERSION'             | "6"
        end

        with_them do
          context "when set in ENV" do
            before do
              stub_env(version_file, version)
            end

            it 'includes the version from ENV' do
              expect(subject.variables[version_file]).to eq(version)
            end
          end

          context "when set in a file" do
            before do
              allow(File).to receive(:read).and_call_original
              stub_env(version_file, nil)
            end

            it 'includes the version from the file' do
              expect(File).to receive(:read).with(version_file).and_return(version)
              expect(subject.variables[version_file]).to eq(version)
            end
          end
        end
      end
    end
  end

  describe Trigger::CNG do
    before do
      stub_env('CNG_SKIP_REDUNDANT_JOBS', 'false')
      stub_env('GLCI_ASSETS_IMAGE_TAG', 'assets_tag')
    end

    describe '#variables' do
      it 'does not include redundant variables' do
        expect(subject.variables).not_to include('TRIGGER_SOURCE', 'TRIGGERED_USER')
      end

      it 'invokes the trigger with expected variables' do
        expect(subject.variables).to include('FORCE_RAILS_IMAGE_BUILDS' => 'true')
      end

      describe "TRIGGER_BRANCH" do
        context 'when CNG_BRANCH is not set' do
          context 'with gitlab-org' do
            before do
              stub_env('CI_PROJECT_NAMESPACE', 'gitlab-org')
            end

            it 'sets TRIGGER_BRANCH to master if the commit ref is master' do
              stub_env('CI_COMMIT_REF_NAME', 'master')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', nil)
              expect(subject.variables['TRIGGER_BRANCH']).to eq('master')
            end

            it 'sets the TRIGGER_BRANCH to master if the commit is part of an MR targeting master' do
              stub_env('CI_COMMIT_REF_NAME', 'feature_branch')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', 'master')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('master')
            end

            it 'sets TRIGGER_BRANCH to stable branch if the commit ref is a stable branch' do
              stub_env('CI_COMMIT_REF_NAME', '16-6-stable-ee')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('16-6-stable')
            end

            it 'sets the TRIGGER_BRANCH to stable branch if the commit is part of an MR targeting stable branch' do
              stub_env('CI_COMMIT_REF_NAME', 'feature_branch')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', '16-6-stable-ee')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('16-6-stable')
            end
          end

          context 'with gitlab-cn' do
            before do
              stub_env('CI_PROJECT_NAMESPACE', 'gitlab-cn')
            end

            it 'sets TRIGGER_BRANCH to main-jh if commit ref is main-jh' do
              stub_env('CI_COMMIT_REF_NAME', 'main-jh')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', nil)
              expect(subject.variables['TRIGGER_BRANCH']).to eq('main-jh')
            end

            it 'sets the TRIGGER_BRANCH to main-jh if the commit is part of an MR targeting main-jh' do
              stub_env('CI_COMMIT_REF_NAME', 'feature_branch')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', 'main-jh')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('main-jh')
            end

            it 'sets TRIGGER_BRANCH to 16-6-stable if commit ref is a stable branch' do
              stub_env('CI_COMMIT_REF_NAME', '16-6-stable-jh')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('16-6-stable')
            end

            it 'sets the TRIGGER_BRANCH to 16-6-stable if the commit is part of an MR targeting 16-6-stable-jh' do
              stub_env('CI_COMMIT_REF_NAME', 'feature_branch')
              stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', '16-6-stable-jh')
              expect(subject.variables['TRIGGER_BRANCH']).to eq('16-6-stable')
            end
          end
        end

        context 'when CNG_BRANCH is set' do
          let(:ref) { 'cng_branch' }

          before do
            stub_env('CNG_BRANCH', ref)
          end

          it 'sets TRIGGER_BRANCH to cng_branch' do
            expect(subject.variables['TRIGGER_BRANCH']).to eq(ref)
          end
        end

        context 'when CI_COMMIT_REF_NAME is a stable branch' do
          let(:ref) { '14-10-stable' }

          before do
            stub_env('CI_COMMIT_REF_NAME', "#{ref}-ee")
          end

          it 'sets TRIGGER_BRANCH to the corresponding stable branch' do
            stub_env('CI_PROJECT_NAMESPACE', 'gitlab-org')
            expect(subject.variables['TRIGGER_BRANCH']).to eq(ref)
          end
        end

        context 'when CI_COMMIT_REF_NAME is a stable branch on JH side' do
          let(:ref) { '14-10-stable' }

          before do
            stub_env('CI_COMMIT_REF_NAME', "#{ref}-jh")
          end

          it 'sets TRIGGER_BRANCH to the corresponding stable branch' do
            stub_env('CI_PROJECT_NAMESPACE', 'gitlab-cn')
            expect(subject.variables['TRIGGER_BRANCH']).to eq(ref)
          end
        end
      end

      describe "GITLAB_VERSION" do
        context 'when CI_COMMIT_SHA is set' do
          before do
            stub_env('CI_COMMIT_SHA', 'ci_commit_sha')
          end

          it 'sets GITLAB_VERSION to CI_COMMIT_SHA' do
            expect(subject.variables['GITLAB_VERSION']).to eq('ci_commit_sha')
          end
        end
      end

      describe "GLCI_ASSETS_IMAGE_TAG" do
        context 'when GLCI_ASSETS_IMAGE_TAG is set' do
          it 'sets GITLAB_ASSETS_TAG to GLCI_ASSETS_IMAGE_TAG value' do
            expect(subject.variables['GITLAB_ASSETS_TAG']).to eq('assets_tag')
          end
        end

        context 'when GLCI_ASSETS_IMAGE_TAG is not set' do
          before do
            stub_env('GLCI_ASSETS_IMAGE_TAG', '')
          end

          it 'sets COMPILE_ASSETS to true' do
            expect(subject.variables['COMPILE_ASSETS']).to eq('true')
            expect(subject.variables['GITLAB_ASSETS_TAG']).to be_nil
          end
        end
      end

      describe "GITLAB_TAG" do
        context 'when CI_COMMIT_TAG is set' do
          before do
            stub_env('CI_COMMIT_TAG', 'v1.0')
          end

          it 'sets GITLAB_TAG to true' do
            expect(subject.variables['GITLAB_TAG']).to eq('v1.0')
          end
        end

        context 'when CI_COMMIT_TAG is nil' do
          before do
            stub_env('CI_COMMIT_TAG', nil)
          end

          it 'sets GITLAB_TAG to nil' do
            expect(subject.variables['GITLAB_TAG']).to eq(nil)
          end
        end
      end

      describe "CE_PIPELINE" do
        context 'when Trigger.ee? is true' do
          before do
            allow(Trigger).to receive(:ee?).and_return(true)
          end

          it 'sets CE_PIPELINE to nil' do
            expect(subject.variables['CE_PIPELINE']).to eq(nil)
          end
        end

        context 'when Trigger.ee? is false' do
          before do
            allow(Trigger).to receive(:ee?).and_return(false)
          end

          it 'sets CE_PIPELINE to true' do
            expect(subject.variables['CE_PIPELINE']).to eq('true')
          end
        end
      end

      describe "EE_PIPELINE" do
        context 'when Trigger.ee? is true' do
          before do
            allow(Trigger).to receive(:ee?).and_return(true)
          end

          it 'sets EE_PIPELINE to true' do
            expect(subject.variables['EE_PIPELINE']).to eq('true')
          end
        end

        context 'when Trigger.ee? is false' do
          before do
            allow(Trigger).to receive(:ee?).and_return(false)
          end

          it 'sets EE_PIPELINE to nil' do
            expect(subject.variables['EE_PIPELINE']).to eq(nil)
          end
        end
      end

      describe "GITLAB_REF_SLUG" do
        context 'when CI_COMMIT_TAG is set' do
          before do
            stub_env('CI_COMMIT_TAG', 'true')
          end

          it 'sets GITLAB_REF_SLUG to CI_COMMIT_REF_NAME' do
            expect(subject.variables['GITLAB_REF_SLUG']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end

        context 'when CI_COMMIT_TAG is nil' do
          before do
            stub_env('CI_COMMIT_TAG', nil)
          end

          it 'sets GITLAB_REF_SLUG to CI_COMMIT_SHA' do
            expect(subject.variables['GITLAB_REF_SLUG']).to eq(env['CI_COMMIT_SHA'])
          end
        end
      end

      describe "#version_param_value" do
        using RSpec::Parameterized::TableSyntax

        let(:version_file) { 'GITALY_SERVER_VERSION' }

        where(:raw_version, :expected_version) do
          "1.2.3" | "v1.2.3"
          "1.2.3-rc1" | "v1.2.3-rc1"
          "1.2.3-ee" | "v1.2.3-ee"
          "1.2.3-rc1-ee" | "v1.2.3-rc1-ee"
        end

        with_them do
          context "when set in ENV" do
            before do
              stub_env(version_file, raw_version)
            end

            it 'includes the version from ENV' do
              expect(subject.variables[version_file]).to eq(expected_version)
            end
          end
        end
      end

      describe "#extra_variables" do
        before do
          stub_env('CI_PROJECT_PATH_SLUG', 'project-path')
          stub_env('ARCH_LIST', 'amd64,arm64')
        end

        it 'includes extra variables' do
          expect(subject.variables).to include({
            "FULL_RUBY_VERSION" => RUBY_VERSION,
            "SKIP_JOB_REGEX" => "/final-images-listing/",
            "DEBIAN_IMAGE" => "debian:bookworm-slim",
            "ALPINE_IMAGE" => "alpine:3.20",
            "CONTAINER_VERSION_SUFFIX" => "project-path",
            "CACHE_BUSTER" => "false",
            "ARCH_LIST" => 'amd64,arm64'
          })
        end
      end

      describe 'with skipping redundant jobs' do
        let(:downstream_project_path) { 'gitlab-org/build/cng' }
        let(:ref) { 'main' }
        let(:image_digest) { 'sha256:digest' }
        let(:debian_image) { 'debian:bookworm-slim' }
        let(:alpine_image) { 'alpine:3.20' }

        let(:tree_node) do
          {
            'mode' => '040000',
            'type' => 'tree',
            'id' => 'df239f023af22fc672d31dc50fdd5f593d4481b1',
            'path' => '.gitlab'
          }
        end

        let(:base_tag) { "32a931c622f7ef7728bf8255cca9e8a46d472e85" }
        let(:rails_tag) { "583f93fe69560d7b158073a17a58e723aea598a3" }

        let(:registry_repositories_response) do
          double(auto_paginate: [
            double(name: 'registry/gitlab-base', id: 1), double(name: 'registry/gitlab-rails-ee', id: 2)
          ])
        end

        before do
          stub_env('CNG_SKIP_REDUNDANT_JOBS', 'true')
          stub_env('CNG_BRANCH', ref)
          stub_env('CNG_PROJECT_PATH', downstream_project_path)
          stub_env('CI_PROJECT_PATH_SLUG', 'project-path')
          stub_env('GITLAB_DEPENDENCY_PROXY', '')

          allow(Trigger).to receive(:ee?).and_return(true)

          # mock repo tree and file fetching
          allow(downstream_gitlab_client).to receive(:repo_tree).with(
            downstream_project_path,
            ref: ref,
            per_page: 100
          ).and_return(double(auto_paginate: [tree_node]))
          allow(downstream_gitlab_client).to receive(:file_contents).with(
            downstream_project_path,
            "build-scripts/container_versions.sh",
            ref
          ).and_return("script")
          allow(downstream_gitlab_client).to receive(:file_contents).with(
            downstream_project_path,
            "ci_files/variables.yml",
            ref
          ).and_return("---\nvariables:\n  DEBIAN_IMAGE: '#{debian_image}'\n  ALPINE_IMAGE: '#{alpine_image}'")

          # mock fetching image digest
          allow(HTTParty).to receive(:get).with(
            %r{https://auth\.docker\.io/token\?service=registry\.docker\.io&scope=repository:library/(debian|alpine):pull}
          ).and_return(double(body: '{"token": "token"}', success?: true))
          allow(HTTParty).to receive(:head).with(
            %r{https://registry\.hub\.docker\.com/v2/library/(debian|alpine)/manifests/(bookworm-slim|3\.20)},
            {
              headers: {
                'Authorization' => 'Bearer token',
                'Accept' => 'application/vnd.docker.distribution.manifest.v2+json'
              }
            }
          ).and_return(double(headers: { 'docker-content-digest' => image_digest }, success?: true))

          # mock version calculation script execution
          allow(Open3).to receive(:capture2e).with(
            hash_including({
              "REPOSITORY_TREE" => "#{tree_node['mode']} #{tree_node['type']} #{tree_node['id']}  #{tree_node['path']}",
              "DEBIAN_DIGEST" => image_digest,
              "ALPINE_DIGEST" => image_digest
            }),
            /bash -c 'source (\S+) && get_all_versions'/
          ).and_return(["gitlab-base=#{base_tag}\ngitlab-rails-ee=#{rails_tag}\n", double(success?: true)])

          # mock existing tag check
          allow(downstream_gitlab_client).to receive(:registry_repositories).with(
            downstream_project_path, per_page: 100
          ).and_return(registry_repositories_response)
          allow(downstream_gitlab_client).to receive(:registry_repository_tag).with(
            downstream_project_path, 2, rails_tag
          ).and_return({})
        end

        context "when all of the jobs would be skipped" do
          before do
            allow(downstream_gitlab_client).to receive(:registry_repository_tag).with(
              downstream_project_path, 1, base_tag
            ).and_return({})
          end

          it 'does not skip gitlab-rails job' do
            expect(subject.variables).to include({
              "SKIP_IMAGE_TAGGING" => "true",
              "SKIP_JOB_REGEX" => "/final-images-listing|alpine-stable|debian-stable|gitlab-base/",
              "DEBIAN_IMAGE" => "#{debian_image}@#{image_digest}",
              "DEBIAN_DIGEST" => image_digest,
              "DEBIAN_BUILD_ARGS" => "--build-arg DEBIAN_IMAGE=#{debian_image}@#{image_digest}",
              "ALPINE_IMAGE" => "#{alpine_image}@#{image_digest}",
              "ALPINE_DIGEST" => image_digest,
              "ALPINE_BUILD_ARGS" => "--build-arg ALPINE_IMAGE=#{alpine_image}@#{image_digest}"
            })
          end
        end

        context 'when tag does not exist in repository' do
          let(:response) do
            Gitlab::ObjectifiedHash.new(
              code: 404,
              parsed_response: "Failure",
              request: { base_uri: "gitlab.com", path: "/repository_tag" }
            )
          end

          before do
            allow(downstream_gitlab_client).to receive(:registry_repository_tag).with(
              downstream_project_path, 1, base_tag
            ).and_raise(Gitlab::Error::NotFound.new(response))
          end

          it 'does not skip jobs with non existing tags' do
            expect(subject.variables).to include({
              "SKIP_JOB_REGEX" => "/final-images-listing|alpine-stable|debian-stable|gitlab-rails-ee/"
            })
          end
        end
      end

      describe 'with specific commit sha' do
        let(:downstream_project_path) { 'gitlab-org/build/cng' }
        let(:sha) { '3f1b1cdc5209' }
        let(:trigger_ref) { "trigger-refs/#{sha}" }

        let(:response) do
          Gitlab::ObjectifiedHash.new(
            code: 404,
            parsed_response: "Failure",
            request: { base_uri: "gitlab.com", path: "/branch" }
          )
        end

        before do
          stub_env('CNG_PROJECT_PATH', downstream_project_path)
          stub_env('CNG_COMMIT_SHA', sha)

          allow(downstream_gitlab_client).to receive(:branch).with(downstream_project_path, trigger_ref).and_raise(
            Gitlab::Error::ResponseError.new(response)
          )
          allow(downstream_gitlab_client).to receive(:create_branch).with(downstream_project_path, trigger_ref, sha)
        end

        it "uses trigger ref branch with specific commit sha" do
          expect(subject.variables).to include({
            "TRIGGER_BRANCH" => trigger_ref
          })
        end

        context 'when trigger ref branch creation fails' do
          before do
            allow(downstream_gitlab_client).to receive(:create_branch).and_raise("failed to create branch")
          end

          it "falls back to default ref" do
            expect(subject.variables).to include({
              "TRIGGER_BRANCH" => "master"
            })
          end
        end

        context 'when trigger ref branch creation fails in sha update mr' do
          before do
            stub_env('CI_MERGE_REQUEST_TARGET_BRANCH_NAME', 'renovate-e2e/cng-mirror-digest')

            allow(downstream_gitlab_client).to receive(:create_branch).and_raise("failed to create branch")
          end

          it "raises error" do
            expect { subject.variables }.to raise_error("failed to create branch")
          end
        end
      end
    end
  end

  describe Trigger::Docs do
    let(:downstream_project_path) { 'gitlab-org/technical-writing/docs-gitlab-com' }

    describe '#variables' do
      describe "BRANCH_CE" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/gitlab-foss')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/gitlab-foss' do
          it 'sets BRANCH_CE to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_CE']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "BRANCH_EE" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/gitlab')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/gitlab' do
          it 'sets BRANCH_EE to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_EE']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "BRANCH_RUNNER" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/gitlab-runner')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/gitlab-runner' do
          it 'sets BRANCH_RUNNER to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_RUNNER']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "BRANCH_OMNIBUS" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/omnibus-gitlab')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/omnibus-gitlab' do
          it 'sets BRANCH_OMNIBUS to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_OMNIBUS']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "BRANCH_CHARTS" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/charts/gitlab')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/charts/gitlab' do
          it 'sets BRANCH_CHARTS to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_CHARTS']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "BRANCH_OPERATOR" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/cloud-native/gitlab-operator')
        end

        context 'when CI_PROJECT_PATH is gitlab-org/cloud-native/gitlab-operator' do
          it 'sets BRANCH_OPERATOR to CI_COMMIT_REF_NAME' do
            expect(subject.variables['BRANCH_OPERATOR']).to eq(env['CI_COMMIT_REF_NAME'])
          end
        end
      end

      describe "REVIEW_SLUG" do
        before do
          stub_env('CI_PROJECT_PATH', 'gitlab-org/gitlab-foss')
        end

        context 'when CI_MERGE_REQUEST_IID is set' do
          it 'sets REVIEW_SLUG' do
            expect(subject.variables['REVIEW_SLUG']).to eq("ce-#{env['CI_MERGE_REQUEST_IID']}")
          end
        end

        context 'when CI_MERGE_REQUEST_IID is not set' do
          before do
            stub_env('CI_MERGE_REQUEST_IID', nil)
          end

          it 'sets REVIEW_SLUG' do
            expect(subject.variables['REVIEW_SLUG']).to eq("ce-#{env['CI_COMMIT_REF_SLUG']}")
          end
        end
      end
    end

    describe '.access_token' do
      context 'when DOCS_PROJECT_API_TOKEN is set' do
        let(:docs_hugo_project_api_token) { 'docs_hugo_project_api_token' }

        before do
          stub_env('DOCS_PROJECT_API_TOKEN', docs_hugo_project_api_token)
        end

        it 'returns the docs-specific access token' do
          expect(subject.access_token).to eq(docs_hugo_project_api_token)
        end
      end

      context 'when DOCS_PROJECT_API_TOKEN is not set' do
        before do
          stub_env('DOCS_PROJECT_API_TOKEN', nil)
        end

        it 'returns the default access token' do
          expect(subject.access_token).to eq(Trigger::Base.new.access_token)
        end
      end
    end

    describe '#invoke!' do
      let(:trigger_token) { 'docs_hugo_trigger_token' }
      let(:ref) { 'main' }

      let(:env) do
        super().merge(
          'CI_PROJECT_PATH' => 'gitlab-org/gitlab-foss',
          'DOCS_TRIGGER_TOKEN' => trigger_token
        )
      end

      describe '#downstream_project_path' do
        context 'when DOCS_PROJECT_PATH is set' do
          let(:downstream_project_path) { 'docs_project_path' }

          before do
            stub_env('DOCS_PROJECT_PATH', downstream_project_path)
          end

          it 'triggers the pipeline on the correct project' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end
      end

      describe '#ref' do
        context 'when DOCS_BRANCH is set' do
          let(:ref) { 'docs_branch' }

          before do
            stub_env('DOCS_BRANCH', ref)
          end

          it 'triggers the pipeline on the correct ref' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end
      end
    end

    describe '#cleanup!' do
      let(:downstream_environment_response) { double('downstream_environment', id: 42) }
      let(:downstream_environments_response) { [downstream_environment_response] }

      before do
        expect(com_gitlab_client).to receive(:environments)
          .with(downstream_project_path, name: subject.__send__(:downstream_environment))
          .and_return(downstream_environments_response)
        expect(com_gitlab_client).to receive(:stop_environment)
          .with(downstream_project_path, downstream_environment_response.id)
          .and_return(downstream_environment_stopping_response)
      end

      context "when stopping the environment succeeds" do
        let(:downstream_environment_stopping_response) { double('downstream_environment', state: 'stopped') }

        it 'displays a success message' do
          expect(subject).to receive(:puts)
            .with("=> Downstream environment '#{subject.__send__(:downstream_environment)}' stopped.")

          subject.cleanup!
        end
      end

      context "when stopping the environment fails" do
        let(:downstream_environment_stopping_response) { double('downstream_environment', state: 'running') }

        it 'displays a failure message' do
          expect(subject).to receive(:puts)
            .with("=> Downstream environment '#{subject.__send__(:downstream_environment)}' failed to stop.")

          subject.cleanup!
        end
      end
    end

    describe '#app_url' do
      let(:review_slug) { 'ce-123' }

      before do
        allow(subject).to receive(:review_slug).and_return(review_slug)
      end

      it 'returns the correct app URL' do
        expected_url = "https://docs.gitlab.com/upstream-review-mr-#{review_slug}/"
        expect(subject.send(:app_url)).to eq(expected_url)
      end
    end
  end

  describe Trigger::DatabaseTesting do
    describe '#variables' do
      it 'invokes the trigger with expected variables' do
        expect(subject.variables).to include('TRIGGERED_USER_LOGIN' => env['GITLAB_USER_LOGIN'])
      end

      context 'when CI_MERGE_REQUEST_SOURCE_BRANCH_SHA is set' do
        before do
          stub_env('CI_MERGE_REQUEST_SOURCE_BRANCH_SHA', 'ci_merge_request_source_branch_sha')
        end

        it 'sets TOP_UPSTREAM_SOURCE_SHA to ci_merge_request_source_branch_sha' do
          expect(subject.variables['TOP_UPSTREAM_SOURCE_SHA']).to eq('ci_merge_request_source_branch_sha')
        end
      end

      context 'when CI_MERGE_REQUEST_SOURCE_BRANCH_SHA is set as empty' do
        before do
          stub_env('CI_MERGE_REQUEST_SOURCE_BRANCH_SHA', '')
        end

        it 'sets TOP_UPSTREAM_SOURCE_SHA to CI_COMMIT_SHA' do
          expect(subject.variables['TOP_UPSTREAM_SOURCE_SHA']).to eq(env['CI_COMMIT_SHA'])
        end
      end

      context 'when CI_MERGE_REQUEST_SOURCE_BRANCH_SHA is not set' do
        before do
          stub_env('CI_MERGE_REQUEST_SOURCE_BRANCH_SHA', nil)
        end

        it 'sets TOP_UPSTREAM_SOURCE_SHA to CI_COMMIT_SHA' do
          expect(subject.variables['TOP_UPSTREAM_SOURCE_SHA']).to eq(env['CI_COMMIT_SHA'])
        end
      end
    end

    describe '#invoke!' do
      let(:downstream_project_path) { 'gitlab-com/database-team/gitlab-com-database-testing' }
      let(:trigger_token) { 'gitlabcom_database_testing_access_token' }
      let(:ops_api_endpoint) { 'https://ops.gitlab.net/api/v4' }
      let(:ops_api_token) { 'gitlabcom_database_testing_access_token' }
      let(:ops_gitlab_client) { double('ops_gitlab_client') }

      let(:downstream_gitlab_client_endpoint) { ops_api_endpoint }
      let(:downstream_gitlab_client) { ops_gitlab_client }

      let(:ref) { 'master' }
      let(:mr_notes) { [double(body: described_class::IDENTIFIABLE_NOTE_TAG)] }

      let(:env) do
        super().merge(
          'GITLABCOM_DATABASE_TESTING_TRIGGER_TOKEN' => trigger_token
        )
      end

      before do
        allow(Gitlab).to receive(:client)
          .with(
            endpoint: com_api_endpoint,
            private_token: com_api_token
          )
          .and_return(com_gitlab_client)

        allow(Gitlab).to receive(:client)
          .with(
            endpoint: downstream_gitlab_client_endpoint
          )
          .and_return(downstream_gitlab_client)

        allow(com_gitlab_client).to receive(:merge_request_notes)
          .with(
            env['CI_PROJECT_PATH'],
            env['CI_MERGE_REQUEST_IID']
          )
          .and_return(double(auto_paginate: mr_notes))
      end

      it 'invokes the trigger with expected variables' do
        expect_run_trigger_with_params

        subject.invoke!
      end

      describe '#downstream_project_path' do
        context 'when GITLABCOM_DATABASE_TESTING_PROJECT_PATH is set' do
          let(:downstream_project_path) { 'gitlabcom_database_testing_project_path' }

          before do
            stub_env('GITLABCOM_DATABASE_TESTING_PROJECT_PATH', downstream_project_path)
          end

          it 'triggers the pipeline on the correct project' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end
      end

      describe '#ref' do
        context 'when GITLABCOM_DATABASE_TESTING_TRIGGER_REF is set' do
          let(:ref) { 'gitlabcom_database_testing_trigger_ref' }

          before do
            stub_env('GITLABCOM_DATABASE_TESTING_TRIGGER_REF', ref)
          end

          it 'triggers the pipeline on the correct ref' do
            expect_run_trigger_with_params

            subject.invoke!
          end
        end
      end

      context 'when no MR notes with the identifier exist yet' do
        let(:mr_notes) { [double(body: 'hello world')] }

        it 'posts a new note' do
          expect_run_trigger_with_params
          expect(com_gitlab_client).to receive(:create_merge_request_note)
            .with(
              env['CI_PROJECT_PATH'],
              env['CI_MERGE_REQUEST_IID'],
              instance_of(String)
            )
            .and_return(double(id: 42))

          subject.invoke!
        end
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
