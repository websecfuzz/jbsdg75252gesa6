# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Create, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_flow_create, params) }
  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      public: true
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item or version' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when graphql params are invalid' do
    let(:name) { nil }
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include(
        'provided invalid value for',
        'name (Expected value to not be null)',
        'description (Expected value to not be null)'
      )
    end
  end

  context 'when model params are invalid' do
    let(:name) { '' }
    let(:description) { '' }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_flow_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank"
      )
      expect(graphql_data_at(:ai_catalog_flow_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data' do
    execute

    item = Ai::Catalog::Item.last
    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      item_type: Ai::Catalog::Item::FLOW_TYPE.to_s,
      public: true
    )
    expect(item.versions.first).to have_attributes(
      schema_version: 1,
      version: 'v1.0.0-draft',
      definition: {
        triggers: []
      }.stringify_keys
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_flow_create, :item)).to match a_hash_including(
      'name' => name,
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'description' => description
    )
  end
end
