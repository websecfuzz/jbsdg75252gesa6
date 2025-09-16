# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::RelatedEpicLinks::ListService, feature_category: :team_planning do
  let(:epics) { Epic.where(id: [epic1.id, epic2.id, epic3.id]) }

  let_it_be(:group) { create(:group) }
  let_it_be(:epic1) { create(:epic, group: group) }
  let_it_be(:epic2) { create(:epic, group: group) }
  let_it_be(:epic3) { create(:epic, group: group) }
  let_it_be(:epic4) { create(:epic, group: group) }
  let_it_be(:epic5) { create(:epic, group: group) }
  let_it_be(:related_epic_link1) { create(:related_epic_link, source: epic1, target: epic2) }
  let_it_be(:related_epic_link2) { create(:related_epic_link, source: epic3, target: epic4) }
  let_it_be(:other_related_epic) { create(:related_epic_link, source: epic4, target: epic5) }
  let_it_be(:other_work_item_link) do
    create(:work_item_link, source: epic1.work_item, target: create(:work_item, :issue, namespace: group))
  end

  subject(:execute) { described_class.new(epics, group).execute }

  describe '#execute' do
    context 'when related_epic_links_from_work_items feature flag is enabled' do
      before do
        stub_feature_flags(related_epic_links_from_work_items: group)
      end

      it 'returns related work item links for epics' do
        expect(execute).to contain_exactly(related_epic_link1.related_work_item_link,
          related_epic_link2.related_work_item_link)
        expect(execute.first.class).to eq(::WorkItems::RelatedWorkItemLink)
      end
    end

    context 'when related_epic_links_from_work_items feature flag is disabled' do
      before do
        stub_feature_flags(related_epic_links_from_work_items: false)
      end

      it 'returns related epic links' do
        expect(execute).to contain_exactly(related_epic_link1, related_epic_link2)
        expect(execute.first.class).to eq(Epic::RelatedEpicLink)
      end
    end
  end
end
