# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::OldConfigValuesExtractor, feature_category: :workspaces do
  include_context "with constant modules"

  let_it_be(:user) { create(:user) }
  let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }
  let_it_be(:workspace_name) { "workspace-name" }
  let(:desired_state) { states_module::STOPPED }
  let_it_be(:actual_state) { states_module::STOPPED }
  let_it_be(:dns_zone) { "my.dns-zone.me" }
  let_it_be(:labels) { { "some-label": "value", "other-label": "other-value" } }
  let_it_be(:started) { true }
  let_it_be(:include_all_resources) { false }
  let_it_be(:network_policy_enabled) { true }
  let_it_be(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
  let_it_be(:image_pull_secrets) { [{ namespace: "default", name: "secret-name" }] }
  let_it_be(:agent_annotations) { { "some/annotation": "value" } }
  let_it_be(:shared_namespace) { "" }
  let_it_be(:network_policy_egress) do
    [
      {
        except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16],
        allow: "0.0.0.0/0"
      }
    ]
  end

  let_it_be(:max_resources_per_workspace) do
    {
      requests: {
        memory: "512Mi",
        cpu: "0.6"
      },
      limits: {
        memory: "786Mi",
        cpu: "1.5"
      }
    }
  end

  let_it_be(:default_resources_per_workspace_container) do
    {
      requests: {
        memory: "600Mi",
        cpu: "0.5"
      },
      limits: {
        memory: "700Mi",
        cpu: "1.0"
      }
    }
  end

  let_it_be(:workspaces_agent_config) do
    config = create(
      :workspaces_agent_config,
      agent: agent,
      dns_zone: dns_zone,
      image_pull_secrets: image_pull_secrets,
      network_policy_enabled: network_policy_enabled,
      # NOTE: We are stringifying all hashes we set here to ensure that the extracted values are converted to symbols
      default_resources_per_workspace_container: default_resources_per_workspace_container.deep_stringify_keys,
      max_resources_per_workspace: max_resources_per_workspace.deep_stringify_keys,
      labels: labels.deep_stringify_keys,
      annotations: agent_annotations.deep_stringify_keys,
      network_policy_egress: network_policy_egress.map(&:deep_stringify_keys),
      shared_namespace: shared_namespace
    )
    agent.reload
    config
  end

  let_it_be(:workspace) do
    workspaces_agent_config
    create(
      :workspace,
      name: workspace_name,
      agent: agent,
      user: user,
      actual_state: actual_state
    )
  end

  let_it_be(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }

  subject(:extractor) { described_class }

  before do
    workspace.update!(desired_state: desired_state)
  end

  it "extracts the config values" do
    extracted_values = extractor.extract(workspace: workspace)
    expect(extracted_values).to be_a(Hash)
    expect(extracted_values.keys)
      .to eq(
        %i[
          allow_privilege_escalation
          common_annotations
          default_resources_per_workspace_container
          default_runtime_class
          domain_template
          env_secret_name
          file_secret_name
          gitlab_workspaces_proxy_namespace
          image_pull_secrets
          labels
          max_resources_per_workspace
          network_policy_enabled
          network_policy_egress
          processed_devfile_yaml
          replicas
          scripts_configmap_name
          secrets_inventory_annotations
          secrets_inventory_name
          shared_namespace
          use_kubernetes_user_namespaces
          workspace_inventory_annotations
          workspace_inventory_name
        ]
      )

    # NOTE: We don't explicitly test the values that are returned directly from the agent config without processing.
    #       Those are covered by the desired_config_generator tests.

    expect(extracted_values[:common_annotations]).to eq(
      {
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace.name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace.id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )

    expect(extracted_values[:default_resources_per_workspace_container])
      .to eq(default_resources_per_workspace_container)

    expect(extracted_values[:env_secret_name]).to eq("#{workspace.name}-env-var")

    expect(extracted_values[:file_secret_name]).to eq("#{workspace.name}-file")

    expect(extracted_values[:image_pull_secrets]).to eq([{ name: "secret-name", namespace: "default" }])

    expect(extracted_values[:gitlab_workspaces_proxy_namespace]).to eq("gitlab-workspaces")

    expect(extracted_values[:labels]).to eq(
      {
        "agent.gitlab.com/id": agent.id.to_s,
        "other-label": "other-value",
        "some-label": "value"
      }
    )

    expect(extracted_values[:network_policy_enabled]).to be(true)

    expect(extracted_values[:network_policy_egress])
      .to eq([{ allow: "0.0.0.0/0", except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16] }])

    expect(extracted_values[:max_resources_per_workspace]).to eq(max_resources_per_workspace)

    expect(extracted_values[:processed_devfile_yaml]).to eq(workspace.processed_devfile)

    expect(extracted_values[:scripts_configmap_name]).to eq("#{workspace.name}-scripts-configmap")

    expect(extracted_values[:secrets_inventory_annotations]).to eq(
      {
        "config.k8s.io/owning-inventory": "#{workspace.name}-secrets-inventory",
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace.name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace.id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )

    expect(extracted_values[:secrets_inventory_name]).to eq("#{workspace.name}-secrets-inventory")

    expect(extracted_values[:workspace_inventory_annotations]).to eq(
      {
        "config.k8s.io/owning-inventory": "#{workspace.name}-workspace-inventory",
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace.name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace.id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )

    expect(extracted_values[:workspace_inventory_name]).to eq("#{workspace.name}-workspace-inventory")
  end

  describe "devfile_parser_params[:replicas]" do
    subject(:replicas) { extractor.extract(workspace: workspace).fetch(:replicas) }

    context "when desired_state is Running" do
      let(:desired_state) { states_module::RUNNING }
      let(:expected_replicas) { 1 }

      it { is_expected.to eq(expected_replicas) }
    end

    context "when desired_state is not CreationRequested nor Running" do
      let(:desired_state) { states_module::STOPPED }
      let(:expected_replicas) { 0 }

      it { is_expected.to eq(expected_replicas) }
    end
  end

  describe "devfile_parser_params[:labels]" do
    subject(:actual_labels) { extractor.extract(workspace: workspace).fetch(:labels) }

    context "when shared_namespace is not set" do
      let(:expected_labels) do
        {
          "agent.gitlab.com/id": agent.id.to_s,
          "other-label": "other-value",
          "some-label": "value"
        }
      end

      it { is_expected.to eq(expected_labels) }
    end

    context "when shared_namespace is set" do
      let_it_be(:shared_namespace) { "default" }
      let_it_be(:workspace_name) { "workspace-name-shared-namespace" }
      let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }
      let_it_be(:workspaces_agent_config) do
        config = create(
          :workspaces_agent_config,
          agent: agent,
          dns_zone: dns_zone,
          labels: labels.deep_stringify_keys,
          shared_namespace: shared_namespace
        )
        agent.reload
        config
      end

      let_it_be(:workspace) do
        workspaces_agent_config
        create(
          :workspace,
          name: workspace_name,
          agent: agent,
          user: user,
          actual_state: actual_state
        )
      end

      let(:expected_labels) do
        {
          "agent.gitlab.com/id": agent.id.to_s,
          "other-label": "other-value",
          "some-label": "value",
          "workspaces.gitlab.com/id": workspace.id.to_s
        }
      end

      it { is_expected.to eq(expected_labels) }
    end
  end
end
