# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::UpdateService, feature_category: :team_planning do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:note, refind: true) do
    create(:note_on_issue, project: project, author: user)
  end

  let(:note_text) { 'text' }
  let(:opts) { { note: note_text } }

  subject(:service) { described_class.new(project, user, opts) }

  describe '#execute' do
    describe 'publish to status page' do
      let(:execute) { service.execute(note) }
      let(:issue_id) { note.noteable_id }
      let(:emoji_name) { Gitlab::StatusPage::AWARD_EMOJI }

      before do
        create(:award_emoji, user: user, name: emoji_name, awardable: note)
      end

      context 'for text-only update' do
        include_examples 'trigger status page publish'

        context 'without recognized emoji' do
          let(:emoji_name) { AwardEmoji::THUMBS_UP }

          include_examples 'no trigger status page publish'
        end
      end

      context 'for quick action only update' do
        let(:note_text) { "/todo\n" }

        include_examples 'trigger status page publish'
      end

      context 'when update fails' do
        let(:note_text) { '' }

        include_examples 'no trigger status page publish'
      end
    end
  end

  context 'for epics' do
    let_it_be(:epic) { create(:epic) }
    let_it_be(:note) { create(:note, noteable: epic) }

    subject(:service) { described_class.new(nil, user, opts) }

    it 'tracks epic note creation' do
      expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_note_updated_action).with(author: user, namespace: epic.group)

      described_class.new(nil, user, opts).execute(note)
    end
  end

  context 'for group wiki page note' do
    let_it_be(:group) { create(:group) }
    let(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }
    let(:note) do
      create(
        :note,
        project: nil,
        namespace: group,
        noteable: wiki_page_meta,
        author: user,
        note: "Old note"
      )
    end

    before do
      stub_licensed_features(group_wikis: true)
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'update_wiki_page_note' }
      let(:category) { described_class.name }
      let(:namespace) { group }
      let(:project) { nil }

      subject(:track_event) { described_class.new(nil, user, opts).execute(note) }
    end
  end
end
