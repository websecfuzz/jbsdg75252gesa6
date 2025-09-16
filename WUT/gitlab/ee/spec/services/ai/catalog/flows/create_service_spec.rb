# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CreateService, feature_category: :workflow_catalog do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Agent',
      description: 'Description',
      public: true
    }
  end

  subject(:response) { described_class.new(project: project, current_user: user, params: params).execute }

  describe '#execute' do
    shared_examples 'an authorization failure' do
      it 'returns a permission error' do
        expect { response }.not_to change { Ai::Catalog::Item.count }
        expect(response).to be_error
        expect(response.message).to match_array(
          ['You have insufficient permissions'])
      end
    end

    it 'returns success' do
      expect(response).to be_success
    end

    it 'creates a catalog item and version with expected data' do
      expect { response }.to change { Ai::Catalog::Item.count }.by(1)
        .and change { Ai::Catalog::ItemVersion.count }.by(1)

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

    context 'when there is a validation issue' do
      it 'returns the relevant error' do
        params[:name] = nil

        expect { response }.not_to change { Ai::Catalog::Item.count }
        expect(response).to be_error
        expect(response.message).to match_array(["Name can't be blank"])
      end
    end

    context 'when user is a developer' do
      let(:user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'an authorization failure'
    end

    context 'when global_ai_catalog feature flag is disabled' do
      before do
        stub_feature_flags(global_ai_catalog: false)
      end

      it_behaves_like 'an authorization failure'
    end
  end
end
