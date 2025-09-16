# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::RelatedEpicLink, feature_category: :team_planning do
  subject(:entity) { described_class.new(object).as_json }

  let_it_be(:source_epic) { create(:epic) }
  let_it_be(:target_epic) { create(:epic) }

  let_it_be(:related_work_item_link) do
    create(:work_item_link, id: 999, source: source_epic.work_item, target: target_epic.work_item)
  end

  let_it_be(:related_epic_link) do
    # We want to ensure the `related_epic_link.id` gets used, so we set the id to a static value
    create(:related_epic_link, id: 100, source: source_epic, target: target_epic,
      related_work_item_link: related_work_item_link)
  end

  shared_examples 'exposes data correctly' do
    it 'uses the data from the related epic link', :aggregate_failures do
      expect(entity.keys).to contain_exactly(:id, :source_epic, :target_epic, :link_type, :created_at, :updated_at)

      expect(entity[:id]).to eq(100)
      expect(entity[:source_epic][:id]).to eq(source_epic.id)
      expect(entity[:target_epic][:id]).to eq(target_epic.id)
      expect(entity[:link_type]).to eq('relates_to')

      expect(entity[:created_at]).to eq(object.created_at)
      expect(entity[:updated_at]).to eq(object.updated_at)
    end
  end

  context 'when related epic link' do
    let(:object) { related_epic_link }

    it_behaves_like 'exposes data correctly'
  end

  context 'when related work_item link' do
    let(:object) { related_work_item_link }

    it_behaves_like 'exposes data correctly'
  end
end
