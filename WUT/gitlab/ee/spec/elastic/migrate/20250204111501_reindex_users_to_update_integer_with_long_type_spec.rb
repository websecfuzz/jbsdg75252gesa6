# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250204111501_reindex_users_to_update_integer_with_long_type.rb')

RSpec.describe ReindexUsersToUpdateIntegerWithLongType, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250204111501
end
