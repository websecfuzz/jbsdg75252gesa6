# frozen_string_literal: true

class EpicNoteEntity < NoteEntity
  expose :toggle_award_path, if: ->(note, _) { note.emoji_awardable? } do |note|
    toggle_award_emoji_group_epic_note_path(note.noteable.namespace, note.noteable, note)
  end

  expose :path, if: ->(note, _) { note.id } do |note|
    group_epic_note_path(note.noteable.namespace, note.noteable, note)
  end

  private

  def resolved?
    false
  end

  def resolvable?
    false
  end
end
