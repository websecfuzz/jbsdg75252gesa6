# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::InternalPoststartCommandsInserter, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  let(:input_processed_devfile) do
    read_devfile("example.main-container-updated-devfile.yaml.erb")
  end

  let(:expected_processed_devfile_name) { "example.internal-poststart-commands-inserted-devfile.yaml.erb" }
  let(:expected_processed_devfile) { read_devfile(expected_processed_devfile_name) }

  let(:project_path) { "test-project" }
  let(:project) do
    http_url_to_repo = "#{root_url}test-group/#{project_path}.git"
    instance_double("Project", path: project_path, http_url_to_repo: http_url_to_repo) # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end

  let(:context) do
    {
      params: {
        project: project,
        project_ref: "master"
      },
      processed_devfile: input_processed_devfile,
      tools_dir: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{create_constants_module::TOOLS_DIR_NAME}",
      volume_mounts: {
        data_volume: {
          path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
        }
      }
    }
  end

  let(:clone_command) do
    returned_value[:processed_devfile][:commands].find do |cmd|
      cmd[:id] == "gl-clone-project-command"
    end
  end

  let(:clone_unshallow_command) do
    returned_value[:processed_devfile][:commands].find do |cmd|
      cmd[:id] == "gl-clone-unshallow-command"
    end
  end

  let(:workspaces_shallow_clone_project_feature_enabled) { true }

  subject(:returned_value) do
    described_class.insert(context)
  end

  before do
    expect(described_class) # rubocop:disable RSpec/ExpectInHook -- We are intentionally doing an expect here, so we will be forced to remove this code when we remove the feature flag
      .to receive(:workspaces_shallow_clone_project_feature_enabled?)
            .and_return(workspaces_shallow_clone_project_feature_enabled)
  end

  it "updates the devfile" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  it "includes depth option in clone command" do
    expect(clone_command).not_to be_nil
    expect(clone_command[:exec][:commandLine]).to include("--depth 10")
  end

  it "includes unshallow logic in clone command" do
    command_line = clone_unshallow_command[:exec][:commandLine]

    expect(command_line).to include("git fetch --unshallow")
    expect(command_line).to include("clone-unshallow.log")
    expect(command_line).to include("git rev-parse --is-shallow-repository")
  end

  context "when workspaces_shallow_clone_project feature option is disabled" do
    let(:workspaces_shallow_clone_project_feature_enabled) { false }

    it "does not include depth option in clone command" do
      expect(clone_command).not_to be_nil
      expect(clone_command[:exec][:commandLine]).not_to include("--depth")
    end

    it "does not add clone unshallow command" do
      expect(clone_unshallow_command).to be_nil
    end
  end
end
