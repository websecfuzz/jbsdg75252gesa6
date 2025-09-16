# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator, feature_category: :workspaces do
  include ResultMatchers

  include_context "with remote development shared fixtures"

  # noinspection RubyArgCount -- https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:workspace) { create(:workspace, user: user, personal_access_token: personal_access_token) }
  let(:vscode_extension_marketplace) do
    {
      service_url: "service_url",
      item_url: "item_url",
      resource_url_template: "resource_url_template"
    }
  end

  let(:variable_type) { RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE }

  let(:user_provided_variables) do
    [
      { key: "key1", value: "value 1", type: variable_type },
      { key: "key2", value: "value 2", type: variable_type }
    ]
  end

  let(:context) do
    {
      workspace: workspace,
      personal_access_token: personal_access_token,
      user: user,
      vscode_extension_marketplace: vscode_extension_marketplace,
      params: {
        variables: user_provided_variables
      }
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord method
  end

  context "when workspace variables create is successful" do
    let(:valid_variable_type) { RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE }
    let(:variable_type) { valid_variable_type }
    let(:expected_number_of_records_saved) { 19 }

    it "creates the workspace variable records and returns ok result containing original context" do
      expect { result }.to change { workspace.workspace_variables.count }.by(expected_number_of_records_saved)

      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key1").value).to eq("value 1")
      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key2").value).to eq("value 2")

      expect(result).to be_ok_result(context)
    end
  end

  context "when workspace create fails" do
    let(:invalid_variable_type) { 9999999 }
    let(:variable_type) { invalid_variable_type }
    let(:expected_number_of_records_saved) { 17 }

    it "does not create the invalid workspace variable records and returns an error result with model errors" do
      # NOTE: Any valid records will be saved if they are first in the array before the invalid record, but that's OK,
      #       because if we return an err_result, the entire transaction will be rolled back at a higher level.
      expect { result }.to change { workspace.workspace_variables.count }.by(expected_number_of_records_saved)

      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key1")).to be_nil
      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key2")).to be_nil

      expect(result).to be_err_result do |message|
        expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceVariablesModelCreateFailed)
        message.content => { errors: ActiveModel::Errors => errors }
        expect(errors.full_messages).to match([/variable type/i])
      end
    end
  end
end
