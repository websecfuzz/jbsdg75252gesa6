# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::RelatedEpicLinks::DestroyService, feature_category: :team_planning do
  let(:epic) { source_epic }

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:source_epic) { create(:epic, group: group) }
  let_it_be(:target_epic) { create(:epic, group: group) }

  subject(:execute) { described_class.new(related_epic_link, epic, user).execute }

  before do
    stub_licensed_features(epics: true, related_epics: true)
  end

  shared_examples 'success' do
    it 'destroys the related epic link and the work item link' do
      expect { execute }
        .to change { Epic::RelatedEpicLink.count }.by(-1)
        .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)

      expect(execute[:status]).to eq(:success)
      expect(execute[:message]).to eq('Relation was removed')
    end
  end

  shared_examples 'error' do
    before do
      stub_licensed_features(epics: true, related_epics: false)
    end

    it 'does not destroy related epic link or work item' do
      expect { execute }
        .to not_change { Epic::RelatedEpicLink.count }
        .and not_change { WorkItems::RelatedWorkItemLink.count }

      expect(execute[:status]).to eq(:error)
      expect(execute[:message]).to eq("No Related Epic Link found")
    end
  end

  describe '#execute' do
    context 'when no work item link exists for related epic link' do
      let_it_be(:related_epic_link) do
        create(:related_epic_link, source: source_epic, target: target_epic)
      end

      before do
        related_work_item_link = related_epic_link.related_work_item_link
        related_epic_link.update!(related_work_item_link: nil)
        related_work_item_link.destroy!
      end

      it 'calls the legacy service and destroys the related epic link' do
        allow(Epics::RelatedEpicLinks::DestroyService).to receive(:new).and_call_original
        expect(Epics::RelatedEpicLinks::DestroyService).to receive(:new)
          .with(related_epic_link, epic, user, synced_epic: false).and_call_original

        expect { execute }
          .to change { Epic::RelatedEpicLink.count }.by(-1)
          .and not_change { WorkItems::RelatedWorkItemLink.count }

        expect(execute[:status]).to eq(:success)
        expect(execute[:message]).to eq('Relation was removed')
      end
    end

    context 'when work item link exists for related epic link without a foreign key' do
      let_it_be(:related_epic_link) do
        create(:related_epic_link, source: source_epic, target: target_epic)
      end

      before do
        related_epic_link.update!(related_work_item_link: nil)
      end

      it_behaves_like 'success'
    end

    context 'when related epic link has a work item link associated' do
      let_it_be(:related_epic_link) do
        create(:related_epic_link, source: source_epic, target: target_epic)
      end

      context 'when feature flags are enabled' do
        before do
          stub_feature_flags(work_item_epics_ssot: true)
        end

        context 'when epic is source' do
          it_behaves_like 'success'
          it_behaves_like 'error'

          it 'calls the WorkItems::RelatedWorkItemLinks::DestroyService with the correct params' do
            allow(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new).and_call_original
            expect(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new)
              .with(epic.work_item, user, { item_ids: [target_epic.issue_id] }).and_call_original

            execute
          end
        end

        context 'when epic is target' do
          let(:epic) { target_epic }

          it_behaves_like 'success'
          it_behaves_like 'error'

          it 'calls the WorkItems::RelatedWorkItemLinks::DestroyService with the correct params' do
            allow(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new).and_call_original
            expect(WorkItems::RelatedWorkItemLinks::DestroyService).to receive(:new)
              .with(epic.work_item, user, { item_ids: [source_epic.issue_id] }).and_call_original

            execute
          end
        end
      end

      context 'when feature flags are disabled' do
        before do
          stub_feature_flags(work_item_epics_ssot: false)
        end

        it_behaves_like 'success'
        it_behaves_like 'error'

        it 'calls Epics::RelatedEpicLinks::DestroyService' do
          allow(Epics::RelatedEpicLinks::DestroyService).to receive(:new).and_call_original
          expect(Epics::RelatedEpicLinks::DestroyService).to receive(:new)
            .with(related_epic_link, epic, user, synced_epic: false).and_call_original

          execute
        end
      end
    end
  end
end
