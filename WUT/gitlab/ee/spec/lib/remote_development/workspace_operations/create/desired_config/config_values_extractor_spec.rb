# frozen_string_literal: true

require "fast_spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::ConfigValuesExtractor, feature_category: :workspaces do
  include_context "with constant modules"

  let(:workspace_name) { "workspace-name" }
  let(:dns_zone) { "my.dns-zone.me" }
  let(:labels) { { "some-label": "value", "other-label": "other-value" } }
  let(:network_policy_enabled) { true }
  let(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
  let(:image_pull_secrets) { [{ namespace: "default", name: "secret-name" }] }
  let(:agent_annotations) { { "some/annotation": "value" } }
  let(:shared_namespace) { "" }
  let(:allow_privilege_escalation) { true }
  let(:default_runtime_class) { "example-default-runtime-class" }
  let(:use_kubernetes_user_namespaces) { true }
  let(:network_policy_egress) do
    [
      {
        except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16],
        allow: "0.0.0.0/0"
      }
    ]
  end

  let(:max_resources_per_workspace) do
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

  let(:default_resources_per_workspace_container) do
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

  let(:workspaces_agent_config) do
    instance_double("RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      dns_zone: dns_zone,
      image_pull_secrets: image_pull_secrets,
      network_policy_enabled: network_policy_enabled,
      # NOTE: We are stringifying all hashes we set here to ensure that the extracted values are converted to symbols
      default_resources_per_workspace_container: default_resources_per_workspace_container.deep_stringify_keys,
      max_resources_per_workspace: max_resources_per_workspace.deep_stringify_keys,
      labels: labels.deep_stringify_keys,
      annotations: agent_annotations.deep_stringify_keys,
      network_policy_egress: network_policy_egress.map(&:deep_stringify_keys),
      shared_namespace: shared_namespace,
      allow_privilege_escalation: allow_privilege_escalation,
      default_runtime_class: default_runtime_class,
      gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces
    )
  end

  let(:workspace_id) { 1 }
  let(:workspace_desired_state_is_running) { true }
  let(:workspaces_agent_id) { 11 }
  let(:context) do
    {
      workspace_id: workspace_id,
      workspace_name: workspace_name,
      workspace_desired_state_is_running: workspace_desired_state_is_running,
      workspaces_agent_id: workspaces_agent_id,
      workspaces_agent_config: workspaces_agent_config
    }
  end

  subject(:extractor) { described_class }

  it "extracts the config values" do
    extracted_values = extractor.extract(context)
    expect(extracted_values).to be_a(Hash)
    expect(extracted_values.keys)
      .to eq(
        %i[
          allow_privilege_escalation
          common_annotations
          common_annotations_for_partial_reconciliation
          default_resources_per_workspace_container
          default_runtime_class
          domain_template
          env_secret_name
          file_secret_name
          gitlab_workspaces_proxy_namespace
          image_pull_secrets
          labels
          max_resources_per_workspace
          network_policy_egress
          network_policy_enabled
          replicas
          scripts_configmap_name
          secrets_inventory_annotations
          secrets_inventory_name
          shared_namespace
          use_kubernetes_user_namespaces
          workspace_desired_state_is_running
          workspace_id
          workspace_inventory_annotations
          workspace_inventory_annotations_for_partial_reconciliation
          workspace_inventory_name
          workspace_name
          workspaces_agent_config
          workspaces_agent_id
        ]
      )

    # NOTE: We don't explicitly test the values that are returned directly from the agent config without processing.
    #       Those are covered by the desired_config_generator tests.

    expect(extracted_values[:common_annotations]).to eq(
      {
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace_name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace_id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )
    expect(extracted_values[:common_annotations_for_partial_reconciliation]).to eq(
      {
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace_name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace_id.to_s,
        "workspaces.gitlab.com/include-in-partial-reconciliation": "true",
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )
    expect(extracted_values[:default_resources_per_workspace_container])
      .to eq(default_resources_per_workspace_container)
    expect(extracted_values[:env_secret_name]).to eq("#{workspace_name}-env-var")
    expect(extracted_values[:file_secret_name]).to eq("#{workspace_name}-file")
    expect(extracted_values[:image_pull_secrets]).to eq([{ name: "secret-name", namespace: "default" }])
    expect(extracted_values[:gitlab_workspaces_proxy_namespace]).to eq("gitlab-workspaces")
    expect(extracted_values[:labels]).to eq(
      {
        "agent.gitlab.com/id": workspaces_agent_id.to_s,
        "other-label": "other-value",
        "some-label": "value"
      }
    )
    expect(extracted_values[:network_policy_enabled]).to be(true)
    expect(extracted_values[:network_policy_egress])
      .to eq([{ allow: "0.0.0.0/0", except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16] }])
    expect(extracted_values[:max_resources_per_workspace]).to eq(max_resources_per_workspace)
    expect(extracted_values[:scripts_configmap_name]).to eq("#{workspace_name}-scripts-configmap")
    expect(extracted_values[:secrets_inventory_annotations]).to eq(
      {
        "config.k8s.io/owning-inventory": "#{workspace_name}-secrets-inventory",
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace_name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace_id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )
    expect(extracted_values[:secrets_inventory_name]).to eq("#{workspace_name}-secrets-inventory")
    expect(extracted_values[:workspace_inventory_annotations]).to eq(
      {
        "config.k8s.io/owning-inventory": "#{workspace_name}-workspace-inventory",
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace_name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace_id.to_s,
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )
    expect(extracted_values[:workspace_inventory_annotations_for_partial_reconciliation]).to eq(
      {
        "config.k8s.io/owning-inventory": "#{workspace_name}-workspace-inventory",
        "some/annotation": "value",
        "workspaces.gitlab.com/host-template": "{{.port}}-#{workspace_name}.#{dns_zone}",
        "workspaces.gitlab.com/id": workspace_id.to_s,
        "workspaces.gitlab.com/include-in-partial-reconciliation": "true",
        "workspaces.gitlab.com/max-resources-per-workspace-sha256":
          "e3dd9c9741b2b3f07cfd341f80ea3a9d4b5a09b29e748cf09b546e93ff98241c"
      }
    )
    expect(extracted_values[:workspace_inventory_name]).to eq("#{workspace_name}-workspace-inventory")
  end

  describe "devfile_parser_params[:replicas]" do
    subject(:replicas) { extractor.extract(context).fetch(:replicas) }

    context "when desired_state is Running" do
      let(:expected_replicas) { 1 }

      it { is_expected.to eq(expected_replicas) }
    end

    context "when desired_state is not CreationRequested nor Running" do
      let(:workspace_desired_state_is_running) { false }
      let(:expected_replicas) { 0 }

      it { is_expected.to eq(expected_replicas) }
    end
  end

  describe "devfile_parser_params[:labels]" do
    subject(:actual_labels) { extractor.extract(context).fetch(:labels) }

    context "when shared_namespace is not set" do
      let(:expected_labels) do
        {
          "agent.gitlab.com/id": workspaces_agent_id.to_s,
          "other-label": "other-value",
          "some-label": "value"
        }
      end

      it { is_expected.to eq(expected_labels) }
    end

    context "when shared_namespace is set" do
      let(:shared_namespace) { "default" }
      let(:workspace_name) { "workspace-name-shared-namespace" }
      let(:expected_labels) do
        {
          "agent.gitlab.com/id": workspaces_agent_id.to_s,
          "other-label": "other-value",
          "some-label": "value",
          "workspaces.gitlab.com/id": workspace_id.to_s
        }
      end

      it { is_expected.to eq(expected_labels) }
    end
  end
end
