# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::LfsObjectReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:lfs_object, :with_file) }

  include_examples 'a blob replicator'
end
