# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Console::Choice, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary_node) { create(:geo_node, primary: true, name: "New York") }
  let(:output_stream) { StringIO.new }

  context 'with an instance of the abstract Choice class' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
    end

    it "raises an error when #open is not implemented" do
      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #open")
    end
  end
end
