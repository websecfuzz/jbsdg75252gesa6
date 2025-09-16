# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::ScriptsConfigmapAppender, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:files) { RemoteDevelopment::Files }
  let(:annotations) { { a: "1" } }
  let(:labels) { { b: "2" } }
  let(:name) { "workspacename-scripts-configmap" }
  let(:namespace) { "namespace" }
  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }

  subject(:updated_desired_config) do
    # Make a fake desired config with one existing fake element, to prove we are appending
    desired_config_array = [
      {}
    ]

    described_class.append(
      desired_config_array: desired_config_array,
      name: name,
      namespace: namespace,
      labels: labels,
      annotations: annotations,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events
    )

    desired_config_array
  end

  it "appends ConfigMap to desired_config_array" do
    expect(updated_desired_config.length).to eq(2)

    updated_desired_config => [
      {}, # existing fake element
      {
        apiVersion: api_version,
        metadata: {
          name: configmap_name
        },
        data: data
      },
    ]

    expect(api_version).to eq("v1")
    expect(configmap_name).to eq(name)
    expect(data).to eq(
      "gl-clone-project-command": clone_project_script,
      "gl-clone-unshallow-command": clone_unshallow_script,
      "gl-init-tools-command": files::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
      create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym =>
        internal_blocking_poststart_commands_script,
      create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym =>
        non_blocking_poststart_commands_script(user_command_ids: ["user-defined-command"]),
      "gl-sleep-until-container-is-running-command":
        sleep_until_container_is_running_script,
      "gl-start-sshd-command": files::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT,
      "user-defined-command": "echo 'user-defined postStart command'"
    )
  end

  context "when legacy poststart scripts are used" do
    let(:processed_devfile) do
      yaml_safe_load_symbolized(
        read_devfile_yaml("example.legacy-poststart-in-container-command-processed-devfile.yaml.erb")
      )
    end

    it "appends ConfigMap to desired_config_array" do
      expect(updated_desired_config.length).to eq(2)

      updated_desired_config => [
        {}, # existing fake element
        {
          apiVersion: api_version,
          metadata: {
            name: configmap_name
          },
          data: data
        },
      ]

      expect(api_version).to eq("v1")
      expect(configmap_name).to eq(name)
      expect(data).to eq(
        "gl-clone-project-command": clone_project_script,
        "gl-init-tools-command": files::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
        create_constants_module::LEGACY_RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym =>
          legacy_poststart_commands_script,
        "gl-sleep-until-container-is-running-command":
          sleep_until_container_is_running_script,
        "gl-start-sshd-command": files::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT
      )
    end
  end
end
