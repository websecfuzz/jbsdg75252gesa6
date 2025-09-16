# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticsearchIndexedNamespace, :saas, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  describe 'scope' do
    describe '.namespace_in' do
      let(:records) { create_list(:elasticsearch_indexed_namespace, 3) }

      it 'returns records of the ids' do
        expect(described_class.namespace_in(records.last(2).map(&:id)).to_a).to match_array(records.last(2))
      end
    end
  end

  it_behaves_like 'an elasticsearch indexed container' do
    let_it_be(:namespace) { create(:namespace) }

    let(:container) { :elasticsearch_indexed_namespace }
    let(:container_attributes) { { namespace: namespace } }

    let(:required_attribute) { :namespace_id }

    let(:index_action) do
      expect(ElasticNamespaceIndexerWorker).to receive(:perform_async).with(subject.namespace_id, 'index')
    end

    let(:delete_action) do
      expect(ElasticNamespaceIndexerWorker).to receive(:perform_async).with(subject.namespace_id, 'delete')
    end
  end

  context 'with plans' do
    Plan::PAID_HOSTED_PLANS.each do |plan| # rubocop:disable RSpec/UselessDynamicDefinition -- `plan` used in `let_it_be`
      plan_factory = "#{plan}_plan"
      let_it_be(plan_factory) { create(plan_factory) } # rubocop:disable Rails/SaveBang
    end

    let_it_be(:namespaces) { create_list(:namespace, 3) }
    let_it_be(:subscription1) { create(:gitlab_subscription, namespace: namespaces[2]) }
    let_it_be(:subscription2) { create(:gitlab_subscription, namespace: namespaces[0]) }
    let_it_be(:subscription3) { create(:gitlab_subscription, :premium, namespace: namespaces[1]) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: false)

      described_class.delete_all # reset index status
    end

    def get_indexed_namespaces
      described_class.order(:created_at).pluck(:namespace_id)
    end

    def expect_worker_args(*args)
      expect(ElasticNamespaceIndexerWorker).to receive(:bulk_perform_async).with(array_including([args]))
    end

    describe '.index_first_n_namespaces_of_plan' do
      it 'creates records, scoped by plan and ordered by namespace id' do
        expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache!).and_call_original.exactly(3).times

        ids = namespaces.map(&:id)

        expect_worker_args(ids[0], 'index')
        expect_worker_args(ids[2], 'index')
        expect_worker_args(ids[1], 'index')

        described_class.index_first_n_namespaces_of_plan('ultimate', 1)

        expect(get_indexed_namespaces).to eq([ids[0]])

        described_class.index_first_n_namespaces_of_plan('ultimate', 2)

        expect(get_indexed_namespaces).to eq([ids[0], ids[2]])

        described_class.index_first_n_namespaces_of_plan('premium', 1)

        expect(get_indexed_namespaces).to eq([ids[0], ids[2], ids[1]])
      end
    end

    describe '.unindex_last_n_namespaces_of_plan' do
      before do
        described_class.index_first_n_namespaces_of_plan('ultimate', 2)
        described_class.index_first_n_namespaces_of_plan('premium', 1)
      end

      it 'creates records, scoped by plan and ordered by namespace id' do
        expect(::Gitlab::CurrentSettings).to receive(:invalidate_elasticsearch_indexes_cache!).and_call_original.exactly(3).times

        ids = namespaces.map(&:id)

        expect_worker_args(ids[2], 'delete')
        expect_worker_args(ids[1], 'delete')
        expect_worker_args(ids[0], 'delete')

        expect(get_indexed_namespaces).to contain_exactly(ids[0], ids[2], ids[1])

        described_class.unindex_last_n_namespaces_of_plan('ultimate', 1)

        expect(get_indexed_namespaces).to contain_exactly(ids[0], ids[1])

        described_class.unindex_last_n_namespaces_of_plan('premium', 1)

        expect(get_indexed_namespaces).to contain_exactly(ids[0])

        described_class.unindex_last_n_namespaces_of_plan('ultimate', 1)

        expect(get_indexed_namespaces).to be_empty
      end
    end
  end
end
