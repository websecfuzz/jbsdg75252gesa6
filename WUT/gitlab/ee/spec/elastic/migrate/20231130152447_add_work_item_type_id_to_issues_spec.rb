# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231130152447_add_work_item_type_id_to_issues.rb')

RSpec.describe AddWorkItemTypeIdToIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231130152447
end
