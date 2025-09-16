# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::Console::TroubleshootReplicationOrVerificationForReplicatorClassMenu,
  feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:menu) do
    described_class.new(
      replicator_class: Geo::LfsObjectReplicator,
      referer: Geo::Console::Exit.new,
      input_stream: input_stream,
      output_stream: output_stream)
  end

  let(:input_stream) { StringIO.new("1\n") }
  let(:output_stream) { StringIO.new }

  it_behaves_like "a Geo console multiple choice menu"
end
