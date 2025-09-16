# frozen_string_literal: true

module Vulnerabilities
  # Ingest bulk dismissed events to enqueue insertion of notes.

  class ProcessBulkDismissedEventsWorker
    include Gitlab::EventStore::Subscriber

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    data_consistency :always

    feature_category :vulnerability_management

    def handle_event(event)
      Note.transaction do
        notes_ids = Note.insert_all!(system_note_attributes_for(event), returning: %w[id])
        SystemNoteMetadata.insert_all!(system_note_metadata_attributes_for(notes_ids))
      end
    end

    def system_note_attributes_for(event)
      event.data[:vulnerabilities].map do |attrs|
        {
          noteable_type: "Vulnerability",
          noteable_id: attrs[:vulnerability_id],
          project_id: attrs[:project_id],
          namespace_id: attrs[:namespace_id],
          system: true,
          note: ::SystemNotes::VulnerabilitiesService.formatted_note(
            'changed',
            :dismissed,
            attrs[:dismissal_reason].titleize,
            attrs[:comment]
          ),
          author_id: attrs[:user_id],
          created_at: now,
          updated_at: now,
          discussion_id: Discussion.discussion_id(Note.new({
            noteable_id: attrs[:id],
            noteable_type: "Vulnerability"
          }))
        }
      end
    end

    def system_note_metadata_attributes_for(results)
      results.map do |row|
        id = row['id']
        {
          note_id: id,
          action: 'vulnerability_dismissed',
          created_at: now,
          updated_at: now
        }
      end
    end

    def now
      @now ||= Time.current.utc
    end
  end
end
