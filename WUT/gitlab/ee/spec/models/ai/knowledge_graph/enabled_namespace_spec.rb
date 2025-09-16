# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::KnowledgeGraph::EnabledNamespace, feature_category: :knowledge_graph do
  describe 'relations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:knowledge_graph_enabled_namespace) }
    it { is_expected.to have_many(:replicas) }
  end

  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :knowledge_graph_enabled_namespace }
  end

  describe 'validations' do
    let_it_be_with_reload(:enabled_namespace) { create(:knowledge_graph_enabled_namespace) }

    describe 'namespace type' do
      using RSpec::Parameterized::TableSyntax

      where(:namespace_type, :valid) do
        nil                | false
        :namespace         | false
        :group             | false
        :project_namespace | true
      end

      with_them do
        it 'validates namespace' do
          ns = namespace_type ? create(namespace_type) : nil # rubocop:disable Rails/SaveBang -- this is factory create

          expect(build(:knowledge_graph_enabled_namespace, namespace: ns).valid?).to eq(valid)
        end
      end
    end
  end
end
