# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Update::Updater, feature_category: :workspaces do
  include ResultMatchers

  include_context "with constant modules"

  subject(:result) do
    described_class.update(workspace: workspace, params: params) # rubocop:disable Rails/SaveBang -- This is not an ActiveRecord method
  end

  let_it_be(:user) { create(:user) }
  let(:personal_access_token) { create(:personal_access_token, user: user) }
  let(:workspace) do
    create(
      :workspace,
      user: user,
      desired_state: states_module::RUNNING,
      personal_access_token: personal_access_token
    )
  end

  let(:new_desired_state) { states_module::STOPPED }
  let(:params) do
    {
      desired_state: new_desired_state
    }
  end

  context 'when workspace update is successful' do
    it 'updates the workspace and returns ok result containing successful message with updated workspace' do
      expect { result }.to change { workspace.reload.desired_state }.to(new_desired_state)

      expect(result)
        .to be_ok_result(RemoteDevelopment::Messages::WorkspaceUpdateSuccessful.new({ workspace: workspace }))
    end
  end

  context 'when workspace update fails' do
    shared_examples 'err result' do |expected_error_details:|
      it 'does not update the db record and returns an error result containing a failed message with model errors' do
        expect { result }.not_to change {
          [
            workspace.reload,
            workspace.personal_access_token.reload
          ]
        }
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceUpdateFailed)
          message.content => { errors: ActiveModel::Errors => errors }
          expect(errors.full_messages).to match([/#{expected_error_details}/i])
        end
      end
    end

    context 'when workspace desired state update fails' do
      let(:new_desired_state) { 'InvalidDesiredState' }

      it_behaves_like 'err result', expected_error_details: %(desired state)
    end

    context 'when personal access token revocation fails' do
      let(:new_desired_state) { states_module::TERMINATED }
      let(:errors) { instance_double(ActiveModel::Errors) }
      let(:exception) { ActiveRecord::ActiveRecordError.new }
      let(:mock_personal_access_token) { instance_double(PersonalAccessToken) }

      before do
        allow(workspace).to receive(:personal_access_token) { mock_personal_access_token }
        allow(mock_personal_access_token).to receive(:revoke!).and_raise(exception)
        allow(mock_personal_access_token).to receive(:errors).and_return(errors)
      end

      it 'does not revoke the token and returns an error result containing a failed message with model errors' do
        expect { result }.not_to change { workspace.reload.updated_at }

        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceUpdateFailed)
          expect(message.content[:errors]).to be(errors)
        end
      end
    end
  end
end
