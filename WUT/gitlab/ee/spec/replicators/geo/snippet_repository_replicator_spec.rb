# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SnippetRepositoryReplicator, feature_category: :geo_replication do
  let(:snippet) { create(:project_snippet, :repository) }
  let(:model_record) { snippet.snippet_repository }

  include_examples 'a repository replicator'
end
