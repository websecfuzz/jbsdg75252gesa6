# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::WorkItems::CustomFieldValueInterface, feature_category: :team_planning do
  let(:fields) { %i[customField] }

  specify { expect(described_class).to have_graphql_fields(fields) }

  describe '.resolve_type' do
    using RSpec::Parameterized::TableSyntax

    where(:custom_field_type, :resolved_type) do
      :text          | ::Types::WorkItems::TextFieldValueType
      :number        | ::Types::WorkItems::NumberFieldValueType
      :single_select | ::Types::WorkItems::SelectFieldValueType
      :multi_select  | ::Types::WorkItems::SelectFieldValueType
    end

    with_them do
      it 'returns the correct type class' do
        object = { custom_field: build(:custom_field, field_type: custom_field_type) }

        expect(described_class.resolve_type(object, nil)).to eq(resolved_type)
      end
    end
  end
end
