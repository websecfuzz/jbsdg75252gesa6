# frozen_string_literal: true

class LabelNote < SyntheticNote
  self.allow_legacy_sti_class = true

  attr_accessor :resource_parent
  attr_reader :events

  def self.from_event(event, resource:, resource_parent:)
    attrs = note_attributes('label', event, resource, resource_parent).merge(events: [event])

    LabelNote.new(attrs)
  end

  def self.from_events(events, resource:, resource_parent:)
    resource ||= events.first.issuable

    label_note = from_event(events.first, resource: resource, resource_parent: resource_parent)
    label_note.events = events.sort_by { |e| e.label&.name.to_s }

    label_note
  end

  def events=(events)
    @events = events

    update_outdated_reference
  end

  def cached_html_up_to_date?(markdown_field)
    true
  end

  def note_html
    label_note_html = Banzai::Renderer.cacheless_render_field(
      self, :note,
      {
        group: group,
        project: project,
        pipeline: :label,
        only_path: true,
        label_url_method: label_url_method
      }
    )

    "<p dir=\"auto\">#{label_note_html}</p>"
  end
  strong_memoize_attr :note_html

  private

  def update_outdated_reference
    events.each do |event|
      if event.outdated_reference?
        event.refresh_invalid_reference
      end
    end
  end

  def note_text(html: false)
    added = labels_str(label_refs_by_action('add').uniq, prefix: 'added')
    removed = labels_str(label_refs_by_action('remove').uniq, prefix: 'removed')

    [added, removed].compact.join(' and ')
  end

  # returns string containing added/removed labels including
  # count of deleted labels:
  #
  # added ~1 ~2 + 1 deleted label
  # added 3 deleted labels
  # added ~1 ~2 labels
  def labels_str(label_refs, prefix: '')
    existing_refs = label_refs.select(&:present?)
    refs_str = existing_refs.empty? ? nil : existing_refs.join(' ')

    deleted = label_refs.count - existing_refs.count
    deleted_str = deleted == 0 ? nil : "#{deleted} deleted"

    return unless refs_str || deleted_str

    label_list_str = [refs_str, deleted_str].compact.join(' + ')
    suffix = ' label'.pluralize(deleted > 0 ? deleted : existing_refs.count)

    "#{prefix} #{label_list_str} #{suffix.squish}"
  end

  def label_refs_by_action(action)
    events.select { |e| e.action == action }.map(&:reference)
  end

  def label_url_method
    return :project_merge_requests_url if noteable.is_a?(MergeRequest)

    resource_parent.is_a?(Group) ? :group_work_items_url : :project_issues_url
  end
end

LabelNote.prepend_mod_with('LabelNote')
