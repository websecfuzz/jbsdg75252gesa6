# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::DesignManagementRepositoryReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:design_management_repository, project: create(:project)) }

  include_examples 'a repository replicator' do
    describe '#verify' do
      context 'when design git repository does not exist' do
        it 'creates a new git repo' do
          expect { model_record.replicator.verify }.to change {
                                                         model_record.repository.raw_repository.exists?
                                                       }.from(false).to(true)

          expect(replicator.primary_checksum).to be_present
        end
      end
    end
  end
end
