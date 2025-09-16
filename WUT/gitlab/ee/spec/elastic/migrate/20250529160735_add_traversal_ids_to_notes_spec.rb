# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250529160735_add_traversal_ids_to_notes.rb')

RSpec.describe AddTraversalIdsToNotes, feature_category: :global_search do
  let(:version) { 20250529160735 }

  describe 'migration', :elastic, :sidekiq_inline do
    include_examples 'migration adds mapping'
  end
end
