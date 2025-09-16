# frozen_string_literal: true

class RemoveCorrectWorkItemTypeIdFromWorkItem < Elastic::Migration
  include ::Search::Elastic::MigrationRemoveFieldsHelper

  batched!
  throttle_delay 1.minute

  private

  def index_name
    ::Search::Elastic::References::WorkItem.index
  end

  def document_type
    'work_item'
  end

  def field_to_remove
    'correct_work_item_type_id'
  end
end
