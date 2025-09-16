# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::LicensedFeaturesType, feature_category: :shared do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build_stubbed(:user) }

  shared_examples_for 'a type that resolves licensed features' do
    where(:field, :licensed_feature) do
      :has_epics_feature | :epics
      :has_issuable_health_status_feature | :issuable_health_status
      :has_issue_weights_feature | :issue_weights
      :has_iterations_feature | :iterations
      :has_linked_items_epics_feature | :linked_items_epics
      :has_okrs_feature | :okrs
      :has_quality_management_feature | :quality_management
      :has_scoped_labels_feature | :scoped_labels
      :has_subepics_feature | :subepics
    end

    with_them do
      describe 'when the feature is enabled' do
        before do
          stub_licensed_features(licensed_feature => true)
        end

        it 'returns true' do
          expect(resolve_field(field, namespace, current_user: user)).to be(true)
        end
      end

      describe 'when the feature is disabled' do
        before do
          stub_licensed_features(licensed_feature => false)
        end

        it 'returns false' do
          expect(resolve_field(field, namespace, current_user: user)).to be(false)
        end
      end
    end
  end

  context 'with a group namespace' do
    it_behaves_like 'a type that resolves licensed features' do
      let_it_be(:namespace) { create(:group) }
    end
  end

  context 'with a project namespace' do
    it_behaves_like 'a type that resolves licensed features' do
      let_it_be(:namespace) { create(:project_namespace) }
    end
  end

  context 'with a user namespace' do
    it_behaves_like 'a type that resolves licensed features' do
      let_it_be(:namespace) { create(:user_namespace) }
    end
  end

  it_behaves_like 'expose all licensed feature fields for the namespace'
end
