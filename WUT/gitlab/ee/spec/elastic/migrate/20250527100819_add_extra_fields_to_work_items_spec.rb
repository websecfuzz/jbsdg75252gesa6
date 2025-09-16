# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250527100819_add_extra_fields_to_work_items.rb')

RSpec.describe AddExtraFieldsToWorkItems, :elastic, feature_category: :global_search do
  let(:version) { 20250527100819 }

  include_examples 'migration adds mapping'
end
