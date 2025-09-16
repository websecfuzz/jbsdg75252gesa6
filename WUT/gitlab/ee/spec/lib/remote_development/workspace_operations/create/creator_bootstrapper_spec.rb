# frozen_string_literal: true

require "fast_spec_helper"

# rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::CreatorBootstrapper, feature_category: :workspaces do
  include_context "with constant modules"

  let(:workspaces_agent_config) do
    instance_double("RemoteDevelopment::WorkspacesAgentConfig", shared_namespace: shared_namespace)
  end

  let(:user) { instance_double("User", id: 1) }

  let(:agent) do
    instance_double("Clusters::Agent", id: 2, unversioned_latest_workspaces_agent_config: workspaces_agent_config)
  end

  let(:context) do
    {
      user: user,
      params: {
        agent: agent
      }
    }
  end

  let(:random_string) { "abcdef" }
  let(:expected_unique_identifier) { "#{agent.id}-#{user.id}-#{random_string}" }

  subject(:returned_value) do
    described_class.bootstrap(context)
  end

  before do
    allow(SecureRandom).to receive(:alphanumeric) { random_string }
  end

  describe "workspace_name" do
    let(:shared_namespace) { "" }

    it "is set in context" do
      expect(returned_value.fetch(:workspace_name)).to eq("workspace-#{expected_unique_identifier}")
    end
  end

  describe "workspace_namespace" do
    context "when shared namespace is set to an empty string" do
      let(:shared_namespace) { "" }

      it "is set in context" do
        expect(returned_value.fetch(:workspace_namespace))
          .to eq("#{create_constants_module::NAMESPACE_PREFIX}-#{agent.id}-#{user.id}-#{random_string}")
      end
    end

    context "when shared namespace is set to a value" do
      let(:shared_namespace) { "my-shared-namespace" }

      it "is set in context" do
        expect(returned_value.fetch(:workspace_namespace)).to eq(shared_namespace)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubleReference
