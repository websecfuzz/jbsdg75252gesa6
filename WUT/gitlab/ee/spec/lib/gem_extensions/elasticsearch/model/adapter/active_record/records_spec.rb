# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elasticsearch::Model::Adapter::ActiveRecord::Records, :elastic, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  describe '#records' do
    let(:user) { create(:user) }
    let(:search_options) { { options: { search_level: 'global', current_user: user, project_ids: :any, order_by: 'created_at', sort: 'desc' } } }
    let(:results) { MergeRequest.elastic_search('*', **search_options).records.to_a }

    let!(:new_merge_request) { create(:merge_request) }
    let!(:recent_merge_request) { create(:merge_request, created_at: 1.hour.ago) }
    let!(:old_merge_request) { create(:merge_request, created_at: 7.days.ago) }

    it 'returns results in the same sorted order as they come back from Elasticsearch' do
      ensure_elasticsearch_index!

      expect(results).to eq([new_merge_request, recent_merge_request, old_merge_request])
    end
  end
end
