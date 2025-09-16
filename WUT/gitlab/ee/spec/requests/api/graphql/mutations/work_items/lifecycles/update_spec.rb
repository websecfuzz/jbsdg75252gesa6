# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a custom lifecycle', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { WorkItems::Statuses::SystemDefined::Lifecycle.all.first }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:params) do
    {
      namespace_path: group.full_path,
      id: system_defined_lifecycle.to_gid,
      statuses: [
        status_params_for(system_defined_lifecycle.default_open_status),
        status_params_for(system_defined_in_progress_status),
        status_params_for(system_defined_lifecycle.default_closed_status),
        status_params_for(system_defined_wont_do_status),
        status_params_for(system_defined_lifecycle.default_duplicate_status)
      ],
      default_open_status_index: 0,
      default_closed_status_index: 2,
      default_duplicate_status_index: 4
    }
  end

  let(:mutation) { graphql_mutation(:lifecycle_update, params) }
  let(:mutation_response) { graphql_mutation_response(:lifecycle_update) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  context 'when custom lifecycle does not exist' do
    it 'creates a custom lifecycle' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      expect(mutation_response['lifecycle']).to match(
        a_hash_including(
          'name' => 'Default',
          'statuses' => include(
            a_hash_including('name' => system_defined_lifecycle.default_open_status.name),
            a_hash_including('name' => system_defined_in_progress_status.name),
            a_hash_including('name' => system_defined_lifecycle.default_closed_status.name),
            a_hash_including('name' => system_defined_wont_do_status.name),
            a_hash_including('name' => system_defined_lifecycle.default_duplicate_status.name)
          )
        )
      )
    end
  end

  context 'when custom lifecycle exists' do
    let!(:custom_lifecycle) do
      create(:work_item_custom_lifecycle, name: system_defined_lifecycle.name, namespace: group)
    end

    context 'when system-defined lifecycle is provided' do
      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(
          'Invalid lifecycle type. Custom lifecycle already exists.'
        )
      end
    end

    context 'when custom lifecycle is provided' do
      let(:existing_in_progress_status) do
        create(:work_item_custom_status, name: 'In Progress', category: :in_progress, namespace: group)
      end

      let!(:lifecycle_status) do
        create(:work_item_custom_lifecycle_status,
          lifecycle: custom_lifecycle, status: existing_in_progress_status, namespace: group)
      end

      let(:params) do
        {
          namespace_path: group.full_path,
          id: custom_lifecycle.to_gid,
          statuses: [
            {
              name: 'Ready for development', # new default open status
              color: '#737278',
              description: nil,
              category: 'TO_DO'
            },
            status_params_for(custom_lifecycle.default_open_status),
            status_params_for(existing_in_progress_status),
            {
              name: 'Complete', # new default closed status
              color: '#108548',
              description: nil,
              category: 'DONE'
            },
            status_params_for(custom_lifecycle.default_closed_status),
            status_params_for(custom_lifecycle.default_duplicate_status)
          ],
          default_open_status_index: 0,
          default_closed_status_index: 3,
          default_duplicate_status_index: 5
        }
      end

      before do
        custom_lifecycle.default_open_status.name = "To do"
      end

      it 'updates the lifecycle' do
        post_graphql_mutation(mutation, current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        expect(mutation_response['lifecycle']).to match(
          a_hash_including(
            'name' => custom_lifecycle.name,
            'statuses' => include(
              a_hash_including('name' => 'Ready for development'),
              a_hash_including('name' => 'To do'),
              a_hash_including('name' => existing_in_progress_status.name),
              a_hash_including('name' => 'Complete'),
              a_hash_including('name' => custom_lifecycle.default_closed_status.name),
              a_hash_including('name' => custom_lifecycle.default_duplicate_status.name)
            )
          )
        )
      end
    end
  end

  context 'when invalid input is provided' do
    it 'returns validation error for missing required argument' do
      invalid_params = params.except(:namespace_path)
      mutation = graphql_mutation(:lifecycle_update, invalid_params)

      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "Variable $lifecycleUpdateInput of type LifecycleUpdateInput! was provided invalid value " \
          "for namespacePath (Expected value to not be null)"
      )
    end

    it 'returns validation error for invalid argument value' do
      invalid_params = params.merge(
        statuses: [
          status_params_for(system_defined_lifecycle.default_open_status),
          {
            name: 'Ready for development',
            color: '#737278',
            description: nil,
            category: 'INVALID_CATEGORY'
          },
          status_params_for(system_defined_lifecycle.default_closed_status),
          status_params_for(system_defined_lifecycle.default_duplicate_status)
        ]
      )

      mutation = graphql_mutation(:lifecycle_update, invalid_params)
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_include(
        /Expected "INVALID_CATEGORY" to be one of: TRIAGE, TO_DO, IN_PROGRESS, DONE, CANCELED/
      )
    end
  end

  context 'when work_item_status_feature_flag is disabled' do
    before do
      stub_feature_flags(work_item_status_feature_flag: false)
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to include(
        'This feature is currently behind a feature flag, and it is not available.'
      )
    end
  end

  context 'when user is unauthorized' do
    it 'returns an error' do
      guest = create(:user, guest_of: group)

      post_graphql_mutation(mutation, current_user: guest)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_include(
        "The resource that you are attempting to access does not exist " \
          "or you don't have permission to perform this action"
      )
    end
  end

  def status_params_for(status)
    {
      id: status.to_global_id,
      name: status.name,
      color: status.color,
      description: status.description,
      category: status.category.upcase
    }
  end
end
