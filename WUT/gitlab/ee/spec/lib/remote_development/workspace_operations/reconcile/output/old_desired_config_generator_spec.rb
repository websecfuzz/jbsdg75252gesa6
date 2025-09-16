# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::OldDesiredConfigGenerator, :freeze_time, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  RSpec.shared_examples "includes env and file secrets if the secrets-inventory configmap is present" do
    it "verifies that env and file secrets are included when secrets-inventory configmap exists" do
      secret_configmap = workspace_resources.find do |resource|
        resource.fetch(:kind) == "ConfigMap" && resource.dig(:metadata, :name).match?(/-secrets-inventory$/)
      end

      skip "No secrets-inventory configmap found in workspace resources" unless secret_configmap

      secret_configmap_name = secret_configmap.dig(:metadata, :name)

      workspace_secrets = workspace_resources.select { |resource| resource.fetch(:kind) == "Secret" }

      secret_env = workspace_secrets.find do |resource|
        resource.dig(:metadata, :name).match?(/-env-var$/) &&
          resource.dig(:metadata, :annotations, :"config.k8s.io/owning-inventory") == secret_configmap_name
      end

      secret_file = workspace_secrets.find do |resource|
        resource.dig(:metadata, :name).match?(/-file$/) &&
          resource.dig(:metadata, :annotations, :"config.k8s.io/owning-inventory") == secret_configmap_name
      end

      expect(secret_env).not_to be_nil
      expect(secret_file).not_to be_nil
    end
  end

  describe "#generate_desired_config" do
    let(:logger) { instance_double(Logger) }
    let(:user) { create(:user) }
    let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }
    let(:desired_state) { states_module::RUNNING }
    let(:actual_state) { states_module::STOPPED }
    let(:started) { true }
    let(:desired_state_is_terminated) { false }
    let(:include_all_resources) { true }
    let(:include_scripts_resources) { true }
    let(:legacy_no_poststart_container_command) { false }
    let(:legacy_poststart_container_command) { false }
    let(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }
    let(:network_policy_enabled) { true }
    let(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
    let(:max_resources_per_workspace) { {} }
    let(:default_resources_per_workspace_container) { {} }
    let(:image_pull_secrets) { [] }
    let(:processed_devfile_yaml) { example_processed_devfile_yaml }
    let(:shared_namespace) { "" }
    let(:workspaces_agent_config) do
      config = create(
        :workspaces_agent_config,
        agent: agent,
        image_pull_secrets: image_pull_secrets,
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        max_resources_per_workspace: max_resources_per_workspace,
        network_policy_enabled: network_policy_enabled,
        shared_namespace: shared_namespace
      )
      agent.reload
      config
    end

    let(:workspace) do
      workspaces_agent_config
      create(
        :workspace,
        agent: agent,
        user: user,
        desired_state: desired_state,
        actual_state: actual_state,
        processed_devfile: processed_devfile_yaml
      )
    end

    let(:user_defined_commands) do
      [
        {
          id: "user-defined-command",
          exec: {
            component: "tooling-container",
            commandLine: "echo 'user-defined postStart command'",
            hotReloadCapable: false
          }
        }
      ]
    end

    let(:expected_config) do
      create_config_to_apply(
        workspace: workspace,
        started: started,
        desired_state_is_terminated: desired_state_is_terminated,
        include_network_policy: workspace.workspaces_agent_config.network_policy_enabled,
        include_all_resources: include_all_resources,
        include_scripts_resources: include_scripts_resources,
        legacy_no_poststart_container_command: legacy_no_poststart_container_command,
        legacy_poststart_container_command: legacy_poststart_container_command,
        egress_ip_rules: workspace.workspaces_agent_config.network_policy_egress.map(&:deep_symbolize_keys),
        max_resources_per_workspace: max_resources_per_workspace,
        default_resources_per_workspace_container: default_resources_per_workspace_container,
        allow_privilege_escalation: workspace.workspaces_agent_config.allow_privilege_escalation,
        use_kubernetes_user_namespaces: workspace.workspaces_agent_config.use_kubernetes_user_namespaces,
        default_runtime_class: workspace.workspaces_agent_config.default_runtime_class,
        agent_labels: workspace.workspaces_agent_config.labels.deep_symbolize_keys,
        agent_annotations: workspace.workspaces_agent_config.annotations.deep_symbolize_keys,
        image_pull_secrets: image_pull_secrets.map(&:deep_symbolize_keys),
        shared_namespace: shared_namespace,
        user_defined_commands: user_defined_commands
      )
    end

    subject(:workspace_resources) do
      # noinspection RubyMismatchedArgumentType -- We are passing a test double
      described_class.generate_desired_config(
        workspace: workspace,
        include_all_resources: include_all_resources,
        logger: logger
      )
    end

    it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"

    it "generates the expected config", :unlimited_max_formatted_output_length do
      expect(workspace_resources).to eq(expected_config)
    end

    it "includes the workspace name in all resource names" do
      resources_without_workspace_name_in_name = workspace_resources.reject do |resource|
        resource[:metadata][:name].include?(workspace.name)
      end

      expect(resources_without_workspace_name_in_name).to be_empty
    end

    context "when desired_state terminated" do
      let(:include_all_resources) { true } # Ensure that the terminated behavior overrides the include_all_resources
      let(:desired_state_is_terminated) { true }
      let(:desired_state) { states_module::TERMINATED }

      it "returns expected config with only inventory config maps", :unlimited_max_formatted_output_length do
        actual = workspace_resources
        expected = expected_config
        expect(actual).to eq(expected)

        workspace_resources.each do |resource|
          resource => {
            kind: "ConfigMap",
            metadata: {
              name: String => name
            }
          }

          expect(name).to end_with("-inventory")
          expect(resource).not_to have_key(:data)
        end
      end
    end

    context "when desired_state results in started=true" do
      it "returns expected config with the replicas set to one", :unlimited_max_formatted_output_length do
        actual = workspace_resources
        expected = expected_config
        expect(actual).to eq(expected)
        workspace_resources => [
          *_,
          {
            kind: "Deployment",
            spec: {
              replicas: replicas
            }
          },
          *_
        ]

        expect(replicas).to eq(1)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when desired_state results in started=false" do
      let(:desired_state) { states_module::STOPPED }
      let(:started) { false }

      it "returns expected config with the replicas set to zero" do
        expect(workspace_resources).to eq(expected_config)
        workspace_resources => [
          *_,
          {
            kind: "Deployment",
            spec: {
              replicas: replicas
            }
          },
          *_
        ]
        expect(replicas).to eq(0)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when network policy is disabled for agent" do
      let(:network_policy_enabled) { false }

      it "returns expected config without network policy" do
        expect(workspace_resources).to eq(expected_config)
        network_policy_resource = workspace_resources.select { |resource| resource.fetch(:kind) == "NetworkPolicy" }
        expect(network_policy_resource).to be_empty
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when default_resources_per_workspace_container is not empty" do
      let(:default_resources_per_workspace_container) do
        { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512M" } }
      end

      it "returns expected config with defaults for the container resources set" do
        expect(workspace_resources).to eq(expected_config)
        workspace_resources => [
          *_,
          {
            kind: "Deployment",
            spec: {
              template: {
                spec: {
                  containers: containers
                }
              }
            }
          },
          *_
        ]
        resources_per_workspace_container = containers.map { |container| container.fetch(:resources) }
        expect(resources_per_workspace_container).to all(eq(default_resources_per_workspace_container))
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when there are image-pull-secrets" do
      let(:image_pull_secrets) { [{ name: "secret-name", namespace: "secret-namespace" }] }
      let(:expected_image_pull_secrets_names) { [{ name: "secret-name" }] }

      it "returns expected config with a service account resource configured" do
        expect(workspace_resources).to eq(expected_config)
        service_account_resource = workspace_resources.find { |resource| resource.fetch(:kind) == "ServiceAccount" }
        expect(service_account_resource.to_h.fetch(:imagePullSecrets)).to eq(expected_image_pull_secrets_names)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when shared_namespace is not empty" do
      let(:shared_namespace) { "secret-namespace" }
      let(:expected_pod_selector_labels) do
        { "workspaces.gitlab.com/id": workspace.id.to_s }
      end

      it "returns expected config with no resource quota and explicit pod selector in network policy" do
        expect(workspace_resources).to eq(expected_config)
        resource_quota = workspace_resources.find { |resource| resource.fetch(:kind) == "ResourceQuota" }
        expect(resource_quota).to be_nil
        workspace_resources => [
          *_,
          {
            kind: "NetworkPolicy",
            spec: {
              podSelector: {
                matchLabels: pod_selector_labels,
              }
            }
          },
          *_
        ]
        expect(pod_selector_labels).to eq(expected_pod_selector_labels)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when max_resources_per_workspace is not empty" do
      let(:max_resources_per_workspace) do
        { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512Mi" } }
      end

      it "returns expected config with resource quota set" do
        expect(workspace_resources).to eq(expected_config)
        resource_quota = workspace_resources.find { |resource| resource.fetch(:kind) == "ResourceQuota" }
        expect(resource_quota).not_to be_nil
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when legacy postStart events are present in devfile" do
      let(:legacy_poststart_container_command) { true }
      let(:processed_devfile_yaml) do
        read_devfile_yaml("example.legacy-poststart-in-container-command-processed-devfile.yaml.erb")
      end

      let(:user_defined_commands) { [] }

      it 'returns expected config without script resources' do
        expect(workspace_resources).to eq(expected_config)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when postStart events are not present in devfile" do
      let(:include_scripts_resources) { false }
      let(:legacy_no_poststart_container_command) { true }
      let(:processed_devfile_yaml) do
        read_devfile_yaml("example.legacy-no-poststart-in-container-command-processed-devfile.yaml.erb")
      end

      it "returns expected config without script resources" do
        expect(workspace_resources).to eq(expected_config)
      end

      it_behaves_like "includes env and file secrets if the secrets-inventory configmap is present"
    end

    context "when include_all_resources is false" do
      let(:include_all_resources) { false }

      it "does not include secrets inventory config map" do
        secret_configmap = workspace_resources.find do |resource|
          resource.fetch(:kind) == "ConfigMap" && resource.dig(:metadata, :name).match?(/-secrets-inventory$/)
        end

        expect(secret_configmap).to be_nil
      end

      it "does not include any secrets" do
        secret_env = workspace_resources.find { |resource| resource.fetch(:kind) == "Secret" }
        expect(secret_env).to be_nil
      end

      context "when max_resources_per_workspace is not empty" do
        let(:max_resources_per_workspace) do
          { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512Mi" } }
        end

        it "does not include workspace resource quota" do
          resource_quota = workspace_resources.find { |resource| resource.fetch(:kind) == "ResourceQuota" }
          expect(resource_quota).to be_nil
        end
      end
    end

    context "when DevfileParser returns empty array" do
      before do
        # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
        allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::OldDevfileParser).to receive(:get_all).and_return([])
        # rubocop:enable Layout/LineLength
      end

      it "returns an empty array" do
        expect(workspace_resources).to eq([])
      end
    end
  end
end
