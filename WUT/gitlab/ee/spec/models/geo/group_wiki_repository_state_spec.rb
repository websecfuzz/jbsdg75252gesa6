# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::GroupWikiRepositoryState, :geo, type: :model, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:group_wiki_repository).inverse_of(:group_wiki_repository_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:group_wiki_repository) }
  end

  context 'with loose foreign key on group_wiki_repository_states.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:geo_group_wiki_repository_state, group_id: parent.id) }
    end
  end
end
