# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestone, :elastic, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it_behaves_like 'limited indexing is enabled' do
    let_it_be(:object) { create :milestone, project: project }
  end

  describe 'searching', :sidekiq_inline do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, developers: user) }
    let_it_be(:milestone_1) { create(:milestone, title: 'bla-bla term1', project: project) }
    let_it_be(:milestone_2) { create(:milestone, title: 'bla-bla term2', project: project) }
    let_it_be(:milestone_3) { create(:milestone, project: project) }
    # The milestone you have no access to except as an administrator
    let_it_be(:milestone_4) { create(:milestone, title: 'bla-bla term3') }

    before do
      Elastic::ProcessInitialBookkeepingService.track!(milestone_1, milestone_2, milestone_3, milestone_4)
      ensure_elasticsearch_index!
    end

    it 'searches milestones', :sidekiq_inline do
      options = { search_level: 'global', project_ids: [project.id], current_user: user }

      expect(described_class.elastic_search('(term1 | term2 | term3) +bla-bla', options: options).total_count).to eq(2)

      options = { search_level: 'global', project_ids: :any }
      expect(described_class.elastic_search('bla-bla', options: options).total_count).to eq(3)
    end
  end

  describe 'json' do
    let_it_be(:milestone) { create :milestone }
    let(:expected_hash) do
      milestone.attributes.extract!(
        'id',
        'iid',
        'title',
        'description',
        'project_id',
        'created_at',
        'updated_at'
      ).merge({
        'type' => milestone.es_type,
        'issues_access_level' => milestone.project.issues_access_level,
        'merge_requests_access_level' => milestone.project.merge_requests_access_level,
        'visibility_level' => milestone.project.visibility_level,
        'archived' => milestone.project.archived,
        'schema_version' => Elastic::Latest::MilestoneInstanceProxy::SCHEMA_VERSION,
        'join_field' => { 'name' => milestone.es_type, 'parent' => milestone.es_parent }
      })
    end

    it 'returns json with all needed elements' do
      expect(milestone.__elasticsearch__.as_indexed_json).to eq(expected_hash)
    end
  end

  it_behaves_like 'no results when the user cannot read cross project' do
    let(:record1) { create(:milestone, project: project, title: 'test-milestone') }
    let(:record2) { create(:milestone, project: project2, title: 'test-milestone') }
  end
end
