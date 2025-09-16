# frozen_string_literal: true

module WorkItems
  module LegacyEpics
    module Imports
      class CreateFromImportedEpicService < ::WorkItems::CreateService
        BASE_ATTRIBUTES = %w[
          iid author_id title description confidential imported_from last_edited_at
          closed_at created_at updated_at last_edited_by_id updated_by_id closed_by_id state_id
        ].freeze

        # Associations from lib/gitlab/import_export/group/import_export.yml handled during epic-to-work-item import.
        # Test coverage ensures this const is updated when the YAML changes and vice versa.
        # Be sure to update the service to handle any new import associations should this case arise.
        ADDITIONAL_IMPORT_ASSOCIATIONS = %w[
          award_emoji label_links parent relative_position events notes resource_state_events
        ].freeze

        def initialize(group:, current_user:, epic_object:)
          @group = group
          @current_user = current_user
          @params = {}
          @widget_params = { hierarchy_widget: { parent: epic_object.parent&.work_item,
                                                 relative_position: epic_object&.relative_position } }
          @epic_object = epic_object

          super(
            container: group, perform_spam_check: false, current_user: current_user, params: @params,
            widget_params: @widget_params
          )
        end

        def execute
          work_item = create(new_work_item_object)
          return work_item.synced_epic if work_item.valid?

          raise(ActiveRecord::RecordInvalid, work_item)
        end

        private

        def handle_events(work_item_epic)
          epic_object.events.each do |event|
            event["target_type"] = "WorkItem"
            event["author_id"] = work_item_epic.author_id
            event["target_id"] = work_item_epic.id
            event["group_id"] = work_item_epic.namespace.id
            event.save!
          end
        end

        def handle_notes(work_item_epic)
          epic_object.notes.each do |note|
            note["noteable_type"] = "Issue"
            note["noteable_id"] = work_item_epic.id
            note.save!
          end
        end

        def handle_resource_state_events(work_item_epic)
          epic_object.resource_state_events.each do |event|
            event.epic = nil
            event.issue = work_item_epic
            event.save!
          end
        end

        def new_work_item_object
          work_item_attributes = epic_object.attributes.slice(*BASE_ATTRIBUTES)
          work_item_attributes['namespace_id'] = epic_object.group_id
          work_item_attributes['work_item_type'] = ::WorkItems::Type.default_by_type(:epic)
          work_item_attributes['importing'] = true

          work_item_attributes['award_emoji'] = epic_object.award_emoji.map do |award_emoji|
            award_emoji["awardable_type"] = "WorkItem"
            award_emoji
          end

          work_item_attributes['label_links'] = epic_object.label_links.map do |label_link|
            label_link["target_type"] = "WorkItem"
            label_link
          end

          WorkItem.new(work_item_attributes)
        end

        def run_after_create_callbacks(work_item_epic)
          handle_notes(work_item_epic)
          handle_events(work_item_epic)
          handle_resource_state_events(work_item_epic)

          super
        end

        attr_reader :group, :current_user, :epic_object
      end
    end
  end
end
