# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::DependencyProxyBlobReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:dependency_proxy_blob) }

  include_examples 'a blob replicator'
end
