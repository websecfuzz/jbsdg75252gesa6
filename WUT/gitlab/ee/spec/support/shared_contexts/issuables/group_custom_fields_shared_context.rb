# frozen_string_literal: true

RSpec.shared_context 'with group configured with custom fields' do
  let_it_be(:group) { create(:group) }

  let_it_be(:issue_type) { create(:work_item_type, :issue) }
  let_it_be(:task_type) { create(:work_item_type, :task) }

  let_it_be(:text_field) do
    create(:custom_field, namespace: group, field_type: 'text', name: 'Custom field text',
      work_item_types: [issue_type])
  end

  let_it_be(:number_field) do
    create(:custom_field, namespace: group, field_type: 'number', name: 'B number field',
      work_item_types: [issue_type])
  end

  let_it_be(:select_field) do
    create(
      :custom_field,
      namespace: group,
      field_type: 'single_select',
      name: 'A single select field',
      work_item_types: [
        issue_type, task_type
      ]
    )
  end

  let_it_be(:select_option_1) { create(:custom_field_select_option, custom_field: select_field) }
  let_it_be(:select_option_2) { create(:custom_field_select_option, custom_field: select_field) }

  let_it_be(:multi_select_field) do
    create(
      :custom_field,
      namespace: group,
      field_type: 'multi_select',
      name: 'Double (multi) select field',
      work_item_types: [
        issue_type, task_type
      ]
    )
  end

  let_it_be(:multi_select_option_1) { create(:custom_field_select_option, custom_field: multi_select_field) }
  let_it_be(:multi_select_option_2) { create(:custom_field_select_option, custom_field: multi_select_field) }
  let_it_be(:multi_select_option_3) { create(:custom_field_select_option, custom_field: multi_select_field) }

  let_it_be(:archived_field) do
    create(:custom_field, :archived, namespace: group, field_type: 'text', work_item_types: [issue_type])
  end

  let_it_be(:field_on_other_type) do
    create(:custom_field, namespace: group, field_type: 'text', work_item_types: [task_type])
  end
end
