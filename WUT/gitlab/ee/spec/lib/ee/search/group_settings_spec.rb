# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Search results for settings", :js, feature_category: :global_search, type: :feature do
  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)

    stub_licensed_features(
      group_level_merge_checks_setting: true,
      group_project_templates: true,
      custom_file_templates_for_namespace: true,
      pages_size_limit: true,
      protected_environments: true,
      push_rules: true
    )

    stub_config(dependency_proxy: { enabled: true })
  end

  it_behaves_like 'all group settings sections exist and have correct anchor links'
end
