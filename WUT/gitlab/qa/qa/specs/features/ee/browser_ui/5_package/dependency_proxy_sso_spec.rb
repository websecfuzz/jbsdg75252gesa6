# frozen_string_literal: true

module QA
  RSpec.describe 'Package', :skip_live_env, :orchestrated, :group_saml,
    requires_admin: 'for various user admin functions' do
    describe 'Dependency Proxy Group SSO', product_group: :container_registry do
      let!(:group) do
        Resource::Sandbox.fabricate! do |sandbox_group|
          sandbox_group.path = "saml_sso_group_with_dependency_proxy_#{SecureRandom.hex(8)}"
        end
      end

      let(:idp_user) { build(:user, username: "saml_user_#{Faker::Number.number(digits: 8)}") }

      # starts a docker Docker container with a plug and play SAML 2.0 Identity Provider (IdP)
      let!(:saml_idp_service) { Flow::Saml.run_saml_idp_service(group.path, [idp_user]) }
      let!(:group_sso_url) { Flow::Saml.enable_saml_sso(group, saml_idp_service, enforce_sso: true) }
      let!(:project) { create(:project, name: 'dependency-proxy-sso-project', group: group) }

      let!(:runner) do
        create(:project_runner,
          name: "qa-runner-#{SecureRandom.hex(6)}",
          tags: ["runner-for-#{project.name}"],
          executor: :docker,
          project: project)
      end

      let(:gitlab_host_with_port) { Support::GitlabAddress.host_with_port }
      let(:dependency_proxy_url) { "#{gitlab_host_with_port}/#{project.group.full_path}/dependency_proxy/containers" }
      let(:image_sha) { 'alpine@sha256:c3d45491770c51da4ef58318e3714da686bc7165338b7ab5ac758e75c7455efb' }

      before do
        Page::Main::Menu.perform(&:sign_out_if_signed_in)

        visit_group_sso_url

        EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)
        Flow::Saml.login_to_idp_if_required(idp_user.username, idp_user.password)
        QA::Flow::User.confirm_user(idp_user)

        visit_group_sso_url

        EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)
      end

      after do
        Flow::Saml.remove_saml_idp_service(saml_idp_service)
        runner.remove_via_api!
      end

      it "pulls an image using the dependency proxy on a group enforced SSO",
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347612' do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              dependency-proxy-pull-test:
                image: "docker:stable"
                services:
                - name: "docker:stable-dind"
                  command: ["--insecure-registry=#{gitlab_host_with_port}"]
                before_script:
                  - apk add curl jq grep
                  - docker login -u "$CI_DEPENDENCY_PROXY_USER" -p "$CI_DEPENDENCY_PROXY_PASSWORD" "$CI_DEPENDENCY_PROXY_SERVER"
                script:
                  - docker pull #{dependency_proxy_url}/#{image_sha}
                  - TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq --raw-output .token)
                  - 'curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1'
                  - docker pull #{dependency_proxy_url}/#{image_sha}
                  - 'curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1'
                tags:
                - "runner-for-#{project.name}"
            YAML
          }
        ])

        project.visit!
        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: project)
        project.visit_job('dependency-proxy-pull-test')
        Page::Project::Job::Show.perform do |job|
          expect(job).to be_successful(timeout: 800)
        end

        group.visit!
        Page::Group::Menu.perform(&:go_to_dependency_proxy)
        Page::Group::DependencyProxy.perform do |index|
          expect(index).to have_blob_count(/Contains [1-9]\d* blobs of images/)
        end
      end

      private

      def visit_group_sso_url
        Runtime::Logger.debug(%(Visiting managed_group_url at "#{group_sso_url}"))

        page.visit group_sso_url
        Support::Waiter.wait_until { current_url == group_sso_url }
      end
    end
  end
end
