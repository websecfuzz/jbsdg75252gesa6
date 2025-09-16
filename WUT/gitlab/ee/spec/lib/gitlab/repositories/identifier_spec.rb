# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Repositories::Identifier, feature_category: :source_code_management do
  # GitLab Starter feature
  context 'with group wiki' do
    let_it_be(:wiki) { create(:group_wiki) }

    it_behaves_like 'parsing gl_repository identifier' do
      let(:record_id) { wiki.group.id }
      let(:identifier) { "group-#{record_id}-wiki" }
      let(:expected_container) { wiki }
      let(:expected_type) { Gitlab::GlRepository::WIKI }
    end
  end
end
