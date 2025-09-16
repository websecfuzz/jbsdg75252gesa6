# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFieldSelectOption, feature_category: :team_planning do
  subject(:custom_field_select_option) { build(:custom_field_select_option) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it 'validates presence of namespace' do
      # prevents copy_namespace_from_custom_field from interfering with the test
      custom_field_select_option.custom_field = nil

      is_expected.to validate_presence_of(:namespace)
    end

    it { is_expected.to validate_presence_of(:custom_field) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }

    describe 'uniqueness of value' do
      let_it_be(:custom_field, reload: true) { create(:custom_field) }

      it 'is invalid for duplicate non-persisted options' do
        custom_field.select_options.build(value: 'An option')
        option = custom_field.select_options.build(value: 'An Option')

        expect(option).not_to be_valid
        expect(option.errors[:value]).to include('has already been taken')
      end

      it 'is invalid if value matches an existing option' do
        create(:custom_field_select_option, custom_field: custom_field, value: 'An option')
        custom_field.reload

        option = custom_field.select_options.build(value: 'An Option')

        expect(option).not_to be_valid
        expect(option.errors[:value]).to include('has already been taken')
      end

      it 'is valid when values are unique' do
        custom_field.select_options.build(value: 'An option 1')
        option = custom_field.select_options.build(value: 'An Option 2')

        expect(option).to be_valid
      end
    end
  end

  describe '#copy_namespace_from_custom_field' do
    let(:custom_field) { build(:custom_field) }

    it 'copies namespace_id from the associated custom field' do
      expect(custom_field_select_option.namespace_id).to be_nil

      custom_field_select_option.custom_field = custom_field
      custom_field_select_option.valid?

      expect(custom_field_select_option.namespace_id).to eq(custom_field.namespace_id)
    end
  end
end
