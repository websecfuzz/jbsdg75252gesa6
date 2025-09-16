# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BitbucketServerImport::ImportPullRequestNotesWorker, feature_category: :importers do
  subject(:worker) { described_class.new }

  it_behaves_like Gitlab::BitbucketServerImport::ObjectImporter
end
