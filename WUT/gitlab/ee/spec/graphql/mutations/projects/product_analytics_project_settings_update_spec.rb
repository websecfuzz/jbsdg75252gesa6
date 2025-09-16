# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Projects::ProductAnalyticsProjectSettingsUpdate, feature_category: :product_analytics do
  include GraphqlHelpers
  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  let_it_be(:current_user) { create(:user) }
  # let_it_be(:current_user) { user }
  let_it_be(:project) { create(:project) }

  describe '#resolve' do
    subject(:resolve) do
      mutation.resolve(
        full_path: project.full_path,
        product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
        product_analytics_data_collector_host: 'https://collector.example.com',
        cube_api_base_url: 'https://cube.example.com',
        cube_api_key: '123-api-key'
      )
    end

    it 'raises an error if the resource is not accessible to the user' do
      expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end

    context 'when the user can update product analytics settings' do
      before_all do
        project.add_owner(current_user)
      end

      context 'when project is a personal project' do
        let_it_be(:namespace) { create(:namespace, owner: current_user) }
        let_it_be(:project) { create(:project, namespace: namespace) }

        it 'raises an error' do
          expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when project is not personal' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, :admin_project, project).and_return(true)
        end

        it 'updates the settings' do
          expect(::Projects::UpdateService).to receive(:new).with(
            project,
            current_user,
            {
              project_setting_attributes: {
                product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
                product_analytics_instrumentation_key: nil,
                product_analytics_data_collector_host: 'https://collector.example.com',
                cube_api_base_url: 'https://cube.example.com',
                cube_api_key: '123-api-key'
              }
            }
          ).and_call_original

          result = mutation.resolve(
            full_path: project.full_path,
            product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
            product_analytics_data_collector_host: 'https://collector.example.com',
            cube_api_base_url: 'https://cube.example.com',
            cube_api_key: '123-api-key'
          )

          expect(result).to include(
            product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
            product_analytics_data_collector_host: 'https://collector.example.com',
            cube_api_base_url: 'https://cube.example.com',
            cube_api_key: '123-api-key',
            errors: []
          )
        end
      end
    end

    context 'when user cannot update product analytics settings' do
      before_all do
        project.add_developer(current_user)
      end

      it 'will raise an error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
