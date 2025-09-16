# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ConfigToApplyShadowRunHandler, feature_category: :workspaces do
  let(:logger) { instance_double("RemoteDevelopment::Logger") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:workspace) { instance_double("RemoteDevelopment::Workspace", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper

  # noinspection RubyMismatchedArgumentType -- We are intentionally passing a double for Workspace and Logger
  subject(:result) do
    described_class.handle(
      workspace: workspace,
      new_config_to_apply_array: new_config_to_apply_array,
      logger: logger,
      include_all_resources: true
    )
  end

  before do
    allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::OldDesiredConfigGenerator)
      .to(receive(:generate_desired_config))
      .with(workspace: workspace, include_all_resources: true, logger: logger)
      .and_return(old_config_to_apply_array)
  end

  context "when config_to_apply are same" do
    let(:old_config_to_apply_array) { [{ kind: "Deployment" }] }
    let(:new_config_to_apply_array) { [{ kind: "Deployment" }] }

    it "returns the value from OldDesiredConfigGenerator" do
      expect(logger).not_to receive(:warn)
      expect(result).to eq(old_config_to_apply_array)
    end
  end

  context "when config_to_apply are different" do
    let(:old_config_to_apply_array) { [{ kind: "Deployment" }] }
    let(:new_config_to_apply_array) { [{ kind: "Service" }] }

    before do
      allow(logger).to receive(:warn)
    end

    it "logs a warning and returns the value from OldDesiredConfigGenerator" do
      # noinspection RubyArgCount -- False positive: Ruby thinks `with` is not supposed to get any argument
      expect(logger)
        .to(receive(:warn))
        .with({
          diff: [%w[~ [0].kind Service Deployment]],
          error_type: "workspaces_reconcile_desired_configs_differ",
          message: "The generated config_to_apply from Create::DesiredConfig::Main and OldDesiredConfigGenerator " \
            "differ.",
          workspace_id: 1
        })
      expect(result).to eq(old_config_to_apply_array)
    end
  end
end
