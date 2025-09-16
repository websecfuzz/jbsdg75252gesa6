# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Initialize Product Analytics', feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(:project_initialize_product_analytics,
      { projectPath: project.full_path },
      'project { id }, errors')
  end

  def mutation_response
    graphql_mutation_response(:project_initialize_product_analytics)
  end

  describe '#resolve' do
    context 'when product analytics is enabled' do
      before do
        allow_next_instance_of(ProductAnalytics::InitializeStackService) do |service|
          allow(service).to receive(:feature_availability_error).and_return(nil)
        end
      end

      context 'when user is a project maintainer' do
        before do
          project.add_maintainer(current_user)
        end

        it_behaves_like 'a working GraphQL mutation'

        it 'enqueues the InitializeSnowplowProductAnalyticsWorker' do
          expect(::ProductAnalytics::InitializeSnowplowProductAnalyticsWorker)
            .to receive(:perform_async).with(project.id).once

          post_graphql_mutation(mutation, current_user: current_user)
        end

        context 'when an initialization is already in progress' do
          before do
            Gitlab::Redis::SharedState.with do |redis|
              redis.set("project:#{project.id}:product_analytics_initializing", 1)
            end
          end

          it_behaves_like 'a mutation that returns errors in the response',
            errors: ['Product analytics initialization is already in progress']
        end
      end

      context 'when user is a project developer' do
        before do
          project.add_developer(current_user)
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['The resource that you are attempting to access does not exist '\
                   'or you don\'t have permission to perform this action']
      end

      context 'when user is not a project member' do
        it_behaves_like 'a mutation that returns top-level errors',
          errors: ['The resource that you are attempting to access does not exist '\
                   'or you don\'t have permission to perform this action']
      end
    end

    context 'when product analytics is disabled' do
      before do
        project.add_maintainer(current_user)
        stub_application_setting(product_analytics_enabled: false)
      end

      it_behaves_like 'a mutation that returns errors in the response',
        errors: ['Product analytics is disabled']
    end

    context 'when the feature flag is disabled' do
      before do
        project.add_maintainer(current_user)
        stub_application_setting(product_analytics_enabled: true)
        stub_feature_flags(product_analytics_features: false)
      end

      it_behaves_like 'a mutation that returns errors in the response',
        errors: ['Product analytics is disabled for this project']
    end
  end
end
