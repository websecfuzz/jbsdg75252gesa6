# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::NamespaceSetting, type: :model, feature_category: :ai_abstraction_layer do
  describe 'database' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('namespace_ai_settings')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:ai_settings) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:duo_workflow_mcp_enabled).in_array([true, false]) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:namespace_ai_settings)).to be_valid
    end
  end
end
