# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::CustomFields, feature_category: :team_planning do
  include_context 'with group configured with custom fields'

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }

  before do
    stub_licensed_features(custom_fields: true)
  end

  describe '#custom_field_values' do
    subject(:custom_field_values) { described_class.new(work_item).custom_field_values }

    context 'when fields have values' do
      before do
        create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'text value')
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 10)

        create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
          custom_field_select_option: select_option_2)

        create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
          custom_field_select_option: multi_select_option_3)
        create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
          custom_field_select_option: multi_select_option_1)
      end

      it 'returns active custom fields with correct values' do
        expect(custom_field_values).to eq(
          [
            { custom_field: select_field, value: [select_option_2] },
            { custom_field: number_field, value: 10 },
            { custom_field: text_field, value: 'text value' },
            { custom_field: multi_select_field, value: [multi_select_option_1, multi_select_option_3] }
          ]
        )
      end
    end

    context 'when some fields do not have values' do
      before do
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 1.5)

        create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
          custom_field_select_option: multi_select_option_3)
      end

      it 'returns active custom fields with nil values when not set' do
        expect(custom_field_values).to eq(
          [
            { custom_field: select_field, value: nil },
            { custom_field: number_field, value: 1.5 },
            { custom_field: text_field, value: nil },
            { custom_field: multi_select_field, value: [multi_select_option_3] }
          ]
        )
      end
    end
  end
end
