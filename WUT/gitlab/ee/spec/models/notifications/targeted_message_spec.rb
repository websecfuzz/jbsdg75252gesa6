# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessage, feature_category: :acquisition do
  describe 'validations' do
    subject { build(:targeted_message) }

    it { is_expected.to validate_presence_of(:target_type) }
    it { is_expected.to validate_presence_of(:targeted_message_namespaces) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:targeted_message_namespaces) }
    it { is_expected.to have_many(:namespaces).through(:targeted_message_namespaces) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:target_type) }

    it_behaves_like 'having unique enum values'
  end
end
