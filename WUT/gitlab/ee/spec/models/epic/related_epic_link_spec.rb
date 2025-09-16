# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epic::RelatedEpicLink, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }

  it do
    is_expected.to belong_to(:related_work_item_link).class_name('WorkItems::RelatedWorkItemLink')
      .with_foreign_key('issue_link_id').inverse_of(:related_epic_link)
  end

  it_behaves_like 'issuable link' do
    let_it_be_with_reload(:issuable_link) { create(:related_epic_link) }
    let_it_be(:issuable) { create(:epic, group: group) }
    let_it_be(:issuable2) { create(:epic, group: group) }
    let_it_be(:issuable3) { create(:epic, group: group) }
    let(:issuable_class) { 'Epic' }
    let(:issuable_link_factory) { :related_epic_link }
  end

  it_behaves_like 'issuables that can block or be blocked' do
    def factory_class
      :related_epic_link
    end

    let(:issuable_type) { :epic }

    let_it_be(:blocked_issuable_1) { create(:epic, group: group) }
    let_it_be(:blocked_issuable_2) { create(:epic, group: group) }
    let_it_be(:blocked_issuable_3) { create(:epic, group: group) }
    let_it_be(:blocking_issuable_1) { create(:epic, group: group) }
    let_it_be(:blocking_issuable_2) { create(:epic, group: group) }
  end

  it { is_expected.to validate_presence_of(:related_work_item_link) }

  describe '.find_or_initialize_from_work_item_link' do
    let_it_be(:group) { create(:group) }
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: group) }

    subject(:find_or_initialize_from_work_item_link) do
      described_class.find_or_initialize_from_work_item_link(work_item_link)
    end

    context 'when the related epic link does not exist' do
      let_it_be_with_reload(:work_item_link) do
        create(:work_item_link, source: epic1.work_item, target: epic2.work_item, link_type: 'relates_to')
      end

      it 'initializes a new related epic link and can be saved' do
        related_epic_link = find_or_initialize_from_work_item_link

        related_epic_link.save!

        expect(related_epic_link.source).to eq(epic1)
        expect(related_epic_link.target).to eq(epic2)
        expect(related_epic_link.link_type).to eq(work_item_link.link_type.to_s)
        expect(related_epic_link.issue_link_id).to eq(work_item_link.id)
      end
    end

    context 'when related epic link already exists' do
      let_it_be(:existing_epic_link) do
        create(:related_epic_link, source: epic1, target: epic2,
          link_type: 'relates_to')
      end

      let(:work_item_link) { existing_epic_link.related_work_item_link }

      context 'when it exists with the same source, target and link_type' do
        it 'finds the existing related epic link' do
          related_epic_link = find_or_initialize_from_work_item_link

          expect(related_epic_link.id).to eq(existing_epic_link.id)
          expect(related_epic_link.related_work_item_link).to eq(work_item_link)

          expect { related_epic_link.save! }
            .to not_change { described_class.count }
            .and not_change { existing_epic_link.reload.related_work_item_link }
        end
      end

      context 'when it does not exist with the same link_type' do
        before do
          existing_epic_link.update!(link_type: 'blocks')
        end

        it 'finds the existing related epic link and sets new link_type from the work item' do
          related_epic_link = find_or_initialize_from_work_item_link

          expect(related_epic_link.id).to eq(existing_epic_link.id)

          expect { related_epic_link.save! }
            .to not_change { described_class.count }
            .and change { existing_epic_link.reload.link_type }.from('blocks').to('relates_to')
        end
      end
    end
  end
end
