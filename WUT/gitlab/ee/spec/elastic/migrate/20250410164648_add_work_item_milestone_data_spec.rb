# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250410164648_add_work_item_milestone_data.rb')

RSpec.describe AddWorkItemMilestoneData, :elastic, feature_category: :global_search do
  let(:version) { 20250410164648 }

  include_examples 'migration adds mapping'
end
