# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Projects::ProjectSettingsUpdate, feature_category: :code_suggestions do
  include GraphqlHelpers
  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let_it_be(:project_without_addon) { create(:project) }

  describe '#resolve' do
    subject(:resolve) do
      args = { full_path: project.full_path }
      args[:duo_features_enabled] = duo_features_enabled if defined?(duo_features_enabled)
      args[:duo_context_exclusion_settings] = duo_context_exclusion_settings if defined?(duo_context_exclusion_settings)

      mutation.resolve(**args)
    end

    let(:duo_features_enabled) { true }
    let(:duo_context_exclusion_settings) { nil }

    it 'raises an error if the resource is not accessible to the user' do
      expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end

    context 'when the user can update duo features enabled' do
      before_all do
        project.add_owner(current_user)
      end

      context 'when duo features are not available' do
        before do
          stub_licensed_features(code_suggestions: false)
        end

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when duo addon is not available' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        it 'raises an error' do
          expect do
            mutation.resolve(full_path: project_without_addon.full_path,
              duo_features_enabled: duo_features_enabled)
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when duo chat is enabled on saas' do
        before do
          stub_licensed_features(code_suggestions: false)
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the setting' do
          expect(::Projects::UpdateService).to receive(:new).with(
            anything,
            anything,
            { project_setting_attributes: { duo_features_enabled: duo_features_enabled } }
          ).and_call_original
          expect(resolve[:project_settings]).to have_attributes(duo_features_enabled: duo_features_enabled)
        end
      end

      context 'when disabling duo features' do
        let(:duo_features_enabled) { false }

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the setting' do
          expect(resolve[:project_settings]).to have_attributes(duo_features_enabled: duo_features_enabled)
        end
      end

      context 'when updating duo context exclusion settings' do
        let(:duo_context_exclusion_settings) { { exclusion_rules: ['*.txt', 'node_modules/'] } }

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'updates the duo context exclusion settings' do
          expect(::Projects::UpdateService).to receive(:new).with(
            anything,
            anything,
            hash_including(project_setting_attributes:
              hash_including(duo_context_exclusion_settings: duo_context_exclusion_settings)
                          )).and_call_original

          resolve
        end
      end

      context 'when not providing any parameters' do
        subject(:resolve_without_params) do
          mutation.resolve(full_path: project.full_path)
        end

        before do
          stub_saas_features(duo_chat_on_saas: true)
        end

        it 'raise an error' do
          expect do
            resolve_without_params
          end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, 'Must provide at least one argument')
        end
      end
    end

    context 'when user cannot update duo features enabled' do
      before_all do
        project.add_developer(current_user)
      end

      it 'will raise an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
