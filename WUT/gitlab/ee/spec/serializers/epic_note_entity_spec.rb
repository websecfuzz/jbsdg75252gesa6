# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicNoteEntity do
  include Gitlab::Routing

  let(:request) { double('request', current_user: user, noteable: note.noteable) }

  let(:entity) { described_class.new(note, request: request) }
  let(:epic) { create(:epic, author: user) }
  let(:note) { create(:note, noteable: epic, author: user) }
  let(:user) { create(:user) }

  subject { entity.as_json }

  it_behaves_like 'note entity'

  it 'always returns resolved? as false' do
    expect(subject[:resolved]).to eq(false)
  end

  it 'always returns resolvable? as false' do
    expect(subject[:resolvable]).to eq(false)
  end

  it 'exposes epic-specific elements' do
    expect(subject).to include(:toggle_award_path, :path)
  end

  context 'on a system note' do
    let(:note) { create(:system_note, noteable: epic, author: user) }
    let!(:note_metadata) { create(:system_note_metadata, note: note, action: 'epic_issue_added') }

    it 'sets system_note_icon_name for epic system notes' do
      expect(subject[:system_note_icon_name]).to eq('issues')
    end
  end
end
