# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Note, :elastic, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it_behaves_like 'limited indexing is enabled' do
    let_it_be(:object) { create :note, project: project }

    describe '#use_elasticsearch?' do
      before do
        create :elasticsearch_indexed_project, project: project
      end

      it 'supports diff notes' do
        notes = []
        notes << create(:diff_note_on_merge_request, note: "term")
        notes << create(:diff_note_on_commit, note: "term")
        notes << create(:legacy_diff_note_on_merge_request, note: "term")
        notes << create(:legacy_diff_note_on_commit, note: "term")

        notes.each do |note|
          create :elasticsearch_indexed_project, project: note.noteable.project

          expect(note.use_elasticsearch?).to eq(true)
        end
      end
    end
  end

  it 'searches notes', :sidekiq_inline do
    project = create :project, :public
    issue = create :issue, project: project

    note = create :note, note: 'bla-bla term1', project: issue.project
    create :note, project: issue.project

    # The note in the project you have no access to except as an administrator
    outside_note = create :note, note: 'bla-bla term2'

    ensure_elasticsearch_index!

    options = { project_ids: [issue.project.id] }

    expect(described_class.elastic_search('term1 | term2', options: options).records).to contain_exactly(note)
    expect(described_class.elastic_search('bla-bla', options: options).records).to contain_exactly(note)
    expect(described_class.elastic_search('bla-bla', options: { project_ids: :any }).records).to contain_exactly(outside_note)
  end

  it 'names elasticsearch queries' do
    described_class.elastic_search('*').total_count

    assert_named_queries("note:match:search_terms", "note:authorized")
  end

  it 'indexes and searches diff notes', :sidekiq_inline do
    notes = []

    notes << create(:diff_note_on_merge_request, note: "term")
    notes << create(:diff_note_on_commit, note: "term")
    notes << create(:legacy_diff_note_on_merge_request, note: "term")
    notes << create(:legacy_diff_note_on_commit, note: "term")

    notes.each do |note|
      note.project.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
    end

    ensure_elasticsearch_index!

    project_ids = notes.map { |note| note.noteable.project.id }
    options = { project_ids: project_ids }

    expect(described_class.elastic_search('term', options: options).total_count).to eq(4)
  end

  it 'does not track system note updates' do
    note = create(:note, :system)

    expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

    note.update!(note: 'some other text here')
  end

  it 'uses same index for Note subclasses', :eager_load do
    Note.subclasses.each do |note_class|
      expect(note_class.index_name).to eq(Note.index_name)
      expect(note_class.document_type).to eq(Note.document_type)
      expect(note_class.__elasticsearch__.mappings.to_hash).to eq(Note.__elasticsearch__.mappings.to_hash)
    end
  end

  context 'for notes on confidential issues' do
    it 'does not find note' do
      issue = create :issue, :confidential

      Sidekiq::Testing.inline! do
        create_notes_for(issue, 'bla-bla term')
        ensure_elasticsearch_index!
      end

      options = { project_ids: [issue.project.id] }

      expect(described_class.elastic_search('term', options: options).total_count).to eq(0)
    end

    it 'finds note when user is authorized to see it', :sidekiq_might_not_need_inline do
      user = create :user
      issue = create :issue, :confidential, author: user
      issue.project.add_guest user

      Sidekiq::Testing.inline! do
        create_notes_for(issue, 'bla-bla term')
        ensure_elasticsearch_index!
      end

      options = { project_ids: [issue.project.id], current_user: user }

      expect(described_class.elastic_search('term', options: options).total_count).to eq(1)
    end

    shared_examples 'notes finder' do |user_type, no_of_notes|
      it "finds #{no_of_notes} notes for #{user_type}", :sidekiq_might_not_need_inline do
        superuser = create(user_type) # rubocop:disable Rails/SaveBang
        issue = create(:issue, :confidential, author: create(:user))

        Sidekiq::Testing.inline! do
          create_notes_for(issue, 'bla-bla term')
          ensure_elasticsearch_index!
        end

        options = { project_ids: [issue.project.id], current_user: superuser }

        expect(described_class.elastic_search('term', options: options).total_count).to eq(no_of_notes)
      end
    end

    context 'when admin mode is enabled', :enable_admin_mode do
      it_behaves_like 'notes finder', :admin, 1
    end

    it_behaves_like 'notes finder', :admin, 0

    it_behaves_like 'notes finder', :auditor, 1

    it 'return notes with matching content for project members', :sidekiq_inline do
      user = create :user
      issue = create :issue, :confidential, author: user

      member = create(:user)
      issue.project.add_developer(member)

      create_notes_for(issue, 'bla-bla term')
      ensure_elasticsearch_index!

      options = { project_ids: [issue.project.id], current_user: member }

      expect(described_class.elastic_search('term', options: options).total_count).to eq(1)
    end

    it 'does not return notes with matching content for project members with guest role', :sidekiq_inline do
      user = create :user
      issue = create :issue, :confidential, author: user

      member = create(:user)
      issue.project.add_guest(member)

      create_notes_for(issue, 'bla-bla term')
      ensure_elasticsearch_index!

      options = { project_ids: [issue.project.id], current_user: member }

      expect(described_class.elastic_search('term', options: options).total_count).to eq(0)
    end
  end

  it_behaves_like 'no results when the user cannot read cross project' do
    let(:issue1) { create(:issue, project: project) }
    let(:issue2) { create(:issue, project: project2) }
    let(:record1) { create :note, note: 'test-note', project: issue1.project, noteable: issue1 }
    let(:record2) { create :note, note: 'test-note', project: issue2.project, noteable: issue2 }
  end

  def create_notes_for(issue, note)
    create :note, note: note, project: issue.project, noteable: issue
    create :note, project: issue.project, noteable: issue
  end
end
