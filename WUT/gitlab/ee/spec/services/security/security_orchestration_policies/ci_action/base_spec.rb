# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiAction::Base,
  feature_category: :security_policy_management do
  describe '#config' do
    it 'raises an error' do
      expect { described_class.new(anything, anything, anything, 0).config }.to raise_error(NotImplementedError)
    end
  end
end
