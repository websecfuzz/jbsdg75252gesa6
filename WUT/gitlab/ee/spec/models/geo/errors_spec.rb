# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Errors, :geo, type: :model, feature_category: :geo_replication do
  describe 'StatusTimeoutError' do
    subject(:error) { described_class::StatusTimeoutError.new }

    it 'returns the correct error message' do
      expect(error.message).to eq('Generating Geo node status is taking too long')
    end
  end
end
