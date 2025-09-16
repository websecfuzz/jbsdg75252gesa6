# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250203130827_reindex_wikis_to_update_integer_with_long_type.rb')

RSpec.describe ReindexWikisToUpdateIntegerWithLongType, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250203130827
end
