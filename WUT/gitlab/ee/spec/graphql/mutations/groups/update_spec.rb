# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Groups::Update, feature_category: :groups_and_projects do
  include GraphqlHelpers
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:params) { { full_path: group.full_path } }

  describe '#resolve' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_saas_features(repositories_web_based_commit_signing: true)
    end

    subject(:mutation) { described_class.new(object: group, context: query_context, field: nil).resolve(**params) }

    context 'when changing group settings' do
      shared_examples 'updating the group settings' do
        it 'updates the settings' do
          expect { mutation }
            .to change { group.reload.duo_features_enabled }.to(false)
            .and change { group.reload.lock_duo_features_enabled }.to(true)
            .and change { group.reload.web_based_commit_signing_enabled }.to(true)
        end

        it 'returns no errors' do
          expect(mutation).to eq(errors: [], group: group)
        end
      end

      shared_examples 'denying access to group' do
        it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
          expect { mutation }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      let_it_be(:params) do
        {
          full_path: group.full_path,
          duo_features_enabled: false,
          lock_duo_features_enabled: true,
          web_based_commit_signing_enabled: true
        }
      end

      where(:user_role, :shared_examples_name) do
        :owner      | 'updating the group settings'
        :maintainer | 'denying access to group'
        :developer  | 'denying access to group'
        :reporter   | 'denying access to group'
        :guest      | 'denying access to group'
        :anonymous  | 'denying access to group'
      end

      with_them do
        before do
          group.send("add_#{user_role}", current_user) unless user_role == :anonymous
        end

        it_behaves_like params[:shared_examples_name]
      end
    end

    context 'when use_web_based_commit_signing_enabled feature flag is disabled' do
      before_all do
        stub_feature_flags(use_web_based_commit_signing_enabled: false)
        group.add_owner(current_user)
      end

      let_it_be(:params) do
        {
          full_path: group.full_path,
          web_based_commit_signing_enabled: true
        }
      end

      it 'does not update the settings' do
        expect { mutation }.not_to change { group.reload.web_based_commit_signing_enabled }
      end
    end
  end
end
