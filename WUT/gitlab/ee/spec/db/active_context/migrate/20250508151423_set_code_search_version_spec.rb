# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/db/active_context/migrate/20250508151423_set_code_search_version.rb')

RSpec.describe SetCodeSearchVersion, feature_category: :code_suggestions do
  let(:version) { 20250508151423 }
  let(:migration) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let_it_be(:collection) { create(:ai_active_context_collection, name: 'gitlab_active_context_code') }

  subject(:migrate) { migration.new.migrate! }

  it 'sets search_embedding_version on the collection' do
    expect { migrate }.to change { collection.reload.search_embedding_version }.from(nil).to(1)
  end
end
