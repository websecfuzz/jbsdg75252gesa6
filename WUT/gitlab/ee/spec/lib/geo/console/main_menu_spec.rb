# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::MainMenu, feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:menu) { described_class.new(input_stream: input_stream, output_stream: output_stream) }
  let(:input_stream) { StringIO.new("1\n") }
  let(:output_stream) { StringIO.new }

  it_behaves_like "a Geo console multiple choice menu"
end
