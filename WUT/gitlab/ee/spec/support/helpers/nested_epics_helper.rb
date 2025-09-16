# frozen_string_literal: true

module NestedEpicsHelper
  def add_parents_to(epic:, count:)
    latest = nil

    count.times do
      latest = create(:epic, :with_work_item_parent, group: epic.group, parent: latest)
    end

    epic.update!(parent: latest)
    create(:parent_link, work_item: epic.work_item, work_item_parent: latest.work_item)

    latest
  end

  def add_children_to(epic:, count:)
    latest = epic

    count.times do
      latest = create(:epic, :with_work_item_parent, group: epic.group, parent: latest)
    end

    latest
  end
end
