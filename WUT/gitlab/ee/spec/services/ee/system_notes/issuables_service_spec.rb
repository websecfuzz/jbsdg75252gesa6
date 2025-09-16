# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SystemNotes::IssuablesService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:author) { create(:user) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:issue1) { create(:issue, project: project) }
  let_it_be(:issue2) { create(:issue, project: project) }
  let_it_be_with_reload(:noteable) { create(:issue, project: project, health_status: 'on_track') }

  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }

  describe '#change_health_status_note' do
    subject { service.change_health_status_note(noteable.health_status_before_last_save) }

    context 'when health_status changed' do
      before do
        noteable.update!(health_status: 'at_risk')
      end

      it_behaves_like 'a system note' do
        let(:action) { 'health_status' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq "changed health status to **at risk**"
      end
    end

    context 'when health_status removed' do
      before do
        noteable.update!(health_status: nil)
      end

      it_behaves_like 'a system note' do
        let(:action) { 'health_status' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq 'removed health status **on track**'
      end
    end

    describe 'events tracking', :snowplow do
      it 'tracks the issue event in usage ping' do
        expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).to receive(:track_issue_health_status_changed_action)
                                                                           .with(author: author, project: project)

        subject
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { Gitlab::UsageDataCounters::IssueActivityUniqueCounter::ISSUE_HEALTH_STATUS_CHANGED }
        let(:user) { author }
        let(:namespace) { project.namespace }
      end
    end
  end

  describe "#change_custom_field_number_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :number) }
    let(:previous_value) { 2 }
    let(:value) { 5 }

    subject { service.change_custom_field_number_type_note(custom_field, previous_value: previous_value, value: value) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when the value is set" do
      let(:previous_value) { nil }
      let(:value) { 5 }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when a value is removed" do
      let(:previous_value) { 2 }
      let(:value) { nil }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">2</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when value is a decimal" do
      context "when there are unnecessary zeros" do
        let(:previous_value) { nil }
        let(:value) { 5.0 }

        it 'strips unnecessary zeros' do
          note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5</code></p>"
          expect(subject.note).to eq note_text
        end
      end

      context "when there are no unnecessary zeros" do
        let(:previous_value) { nil }
        let(:value) { 5.5 }

        it 'strips unnecessary zeros' do
          note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">5.5</code></p>"
          expect(subject.note).to eq note_text
        end
      end
    end
  end

  describe "#change_custom_field_text_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :number) }
    let(:previous_value) { "previous text" }
    let(:value) { "new text" }

    subject { service.change_custom_field_text_type_note(custom_field, previous_value: previous_value, value: value) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when the value is set" do
      let(:previous_value) { nil }
      let(:value) { "new text" }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">#{value}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when a value is removed" do
      let(:previous_value) { "previous text" }
      let(:value) { nil }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">#{previous_value}</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when the value has extra spaces" do
      let(:previous_value) { nil }
      let(:value) { "text  " }

      it 'strips the unnecessary spaces' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">text</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when the value contains html characters" do
      let(:previous_value) { nil }
      let(:value) { "<b>text</b>" }

      it 'escape the html characters' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">&lt;b&gt;text&lt;/b&gt;</code></p>"
        expect(subject.note).to eq note_text
      end
    end
  end

  describe "#change_custom_field_select_type_note" do
    let(:custom_field) { build(:custom_field, field_type: :multi_select) }
    let(:previous_options) { [] }
    let(:new_options) { ["red"] }

    subject { service.change_custom_field_select_type_note(custom_field, previous_options: previous_options, new_options: new_options) }

    it_behaves_like 'a system note', skip_persistence_check: true do
      let(:action) { "custom_field" }
    end

    context "when there is only 1 added options" do
      let(:previous_options) { [] }
      let(:new_options) { ["red"] }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">red</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there are multiple added options" do
      let(:previous_options) { [] }
      let(:new_options) { %w[red black] }

      it 'sets the note text' do
        note_text = "<p>changed #{custom_field.name} to <code class=\"idiff\">red, black</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there is only 1 removed option" do
      let(:previous_options) { ["red"] }
      let(:new_options) { [] }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">red</code></p>"
        expect(subject.note).to eq note_text
      end
    end

    context "when there are multiple removed options" do
      let(:previous_options) { %w[red black] }
      let(:new_options) { [] }

      it 'sets the note text' do
        note_text = "<p>removed #{custom_field.name}: <code class=\"idiff\">red, black</code></p>"
        expect(subject.note).to eq note_text
      end
    end
  end

  describe '#change_progress_note' do
    let_it_be(:noteable) { create(:work_item, :objective, project: project) }
    let_it_be(:progress) { create(:progress, work_item: noteable) }

    subject { service.change_progress_note }

    it_behaves_like 'a system note' do
      let(:action) { 'progress' }
    end

    it 'sets the progress text' do
      expect(subject.note).to eq "changed progress to **#{progress&.progress}%**"
    end
  end

  describe '#change_checkin_reminder_note' do
    let_it_be(:noteable) { create(:work_item, :objective, project: project) }
    let_it_be(:progress) { create(:progress, work_item: noteable) }

    subject { service.change_checkin_reminder_note }

    context 'with a weekly frequency' do
      before do
        progress.reminder_frequency = :weekly
      end

      it_behaves_like 'a system note' do
        let(:action) { 'checkin_reminder' }
      end

      it 'sets the checkin reminder note' do
        expect(subject.note).to eq "set a **#{progress&.reminder_frequency&.humanize(capitalize: false)}** checkin reminder"
      end
    end

    context 'with a frequency of never' do
      it 'sets the checkin reminder note' do
        progress.reminder_frequency = :never

        expect(subject.note).to eq "removed the checkin reminder"
      end
    end
  end

  describe '#publish_issue_to_status_page' do
    let_it_be(:noteable) { create(:issue, project: project) }

    subject { service.publish_issue_to_status_page }

    it_behaves_like 'a system note' do
      let(:action) { 'published' }
    end

    it 'sets the note text' do
      expect(subject.note).to eq 'published this issue to the status page'
    end
  end

  describe '#cross_reference' do
    let(:mentioned_in) { create(:issue, project: project) }

    subject { service.cross_reference(mentioned_in) }

    context 'when noteable is an epic' do
      let(:noteable) { epic }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'cross_reference' }
      end

      it 'tracks epic cross reference event in usage ping' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_cross_referenced)
          .with(author: author, namespace: group)

        subject
      end
    end

    context 'when notable is not an epic' do
      it 'does not tracks epic cross reference event in usage ping' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_cross_referenced)

        subject
      end
    end

    describe '#relate_issuable' do
      let(:noteable) { epic }
      let(:target) { create(:epic) }

      context 'for epics' do
        it 'creates system notes when relating epics' do
          result = service.relate_issuable(target)

          expect(result.note).to eq("marked this epic as related to #{target.to_reference(target.group, full: true)}")
        end
      end

      context 'for work items' do
        let_it_be(:target) { create(:work_item, :objective, project: project) }
        let_it_be(:noteable) { create(:work_item, :objective, project: project) }

        it 'sets the note text with the correct work item type' do
          result = service.relate_issuable(target)

          expect(result.note)
            .to eq("marked this objective as related to #{target.to_reference(target.project)}")
        end
      end
    end
  end

  describe '#unrelate_issuable' do
    let(:noteable) { epic }
    let(:target) { create(:epic) }

    it 'creates system notes when epic gets unrelated' do
      result = service.unrelate_issuable(target)

      expect(result.note).to eq("removed the relation with #{target.to_reference(noteable.group)}")
    end
  end

  describe '#block_issuable' do
    subject(:system_note) { service.block_issuable(noteable_ref) }

    context 'when argument is a single issuable' do
      let_it_be(:noteable_ref) { issue1 }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note when issues gets marked as blocking' do
        expect(system_note.note).to eq "marked this issue as blocking #{issue1.to_reference(project)}"
      end
    end

    context 'when argument is a collection of issuables' do
      let_it_be(:noteable_ref) { [issue1, issue2] }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note mentioning all issuables' do
        expect(system_note.note).to eq(
          "marked this issue as blocking #{issue1.to_reference(project)} and #{issue2.to_reference(project)}"
        )
      end
    end
  end

  describe '#blocked_by_issuable' do
    subject(:system_note) { service.blocked_by_issuable(noteable_ref) }

    context 'when argument is a single issuable' do
      let_it_be(:noteable_ref) { issue1 }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note when issues gets marked as blocked by noteable' do
        expect(system_note.note).to eq "marked this issue as blocked by #{issue1.to_reference(project)}"
      end
    end

    context 'when argument is a collection of issuables' do
      let_it_be(:noteable_ref) { [issue1, issue2] }

      it_behaves_like 'a system note' do
        let(:action) { 'relate' }
      end

      it 'creates system note mentioning all issuables' do
        expect(system_note.note).to eq(
          "marked this issue as blocked by #{issue1.to_reference(project)} and #{issue2.to_reference(project)}"
        )
      end
    end
  end

  describe '#change_color_note' do
    let_it_be(:noteable) { create(:work_item, :epic, namespace: group) }
    let_it_be(:new_color) { create(:color, work_item: noteable, color: '#0052cc') }

    subject(:system_note) { service.change_color_note(previous_color) }

    context 'when argument is a color value' do
      let_it_be(:previous_color) { '#1068bf' }

      it 'creates system note when work item color changes' do
        expect(system_note.note).to eq "changed color from `#{previous_color}` to `#{new_color.color}`"
      end
    end

    context 'when argument is nil and color is present' do
      let_it_be(:previous_color) { nil }

      it 'creates system note when work item color changes' do
        expect(system_note.note).to eq "set color to `#{new_color.color}`"
      end
    end

    context 'when color was destroyed' do
      let_it_be(:previous_color) { nil }

      it 'creates system note when work item color changes' do
        allow(noteable.color).to receive(:destroyed?).and_return(true)

        expect(system_note.note).to eq "removed color `#{new_color.color}`"
      end
    end
  end

  describe '#cross_reference_disallowed?' do
    context 'when noteable is an Epic' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:noteable) { create(:epic, group: group) }

      context 'when mentioned_in is relevant work item' do
        let_it_be(:mentioned_in) { noteable.work_item }

        it 'is true' do
          expect(service.cross_reference_disallowed?(mentioned_in)).to be_truthy
        end
      end

      context 'when mentioned_in is a different epic work item' do
        let_it_be(:epic) { create(:epic, group: group) }
        let_it_be(:mentioned_in) { epic.work_item }

        it 'is false' do
          expect(service.cross_reference_disallowed?(mentioned_in)).to be_falsey
        end
      end
    end
  end

  describe '#amazon_q_called' do
    subject(:system_note) { service.amazon_q_called('test') }

    it_behaves_like 'a system note' do
      let(:action) { 'notify_service' }
    end

    it 'creates system note mentioning q action' do
      expect(system_note.note).to eq "sent test request to Amazon Q"
    end
  end
end
