# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UserRunners, :aggregate_failures, feature_category: :fleet_visibility do
  describe 'POST /user/runners' do
    subject(:request) { post api(path, current_user), params: runner_attrs }

    let_it_be(:group) { create(:group) }
    let_it_be(:group_owner) { create(:user, owner_of: group) }

    let(:runner_attrs) { { runner_type: 'group_type', group_id: group.id } }
    let(:path) { '/user/runners' }

    shared_examples 'creates a runner' do
      it 'creates a runner and logs an audit event' do
        expect do
          request

          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ci::Runner.count }.by(1)
         .and change { AuditEvent.count }.by(1)
      end
    end

    context 'when user has sufficient permissions' do
      let(:current_user) { group_owner }

      it_behaves_like 'creates a runner'
    end

    context 'with request authorized with access token' do
      let(:current_user) { nil }
      let(:token_user) { group_owner }
      let(:pat) { create(:personal_access_token, user: token_user, scopes: [scope]) }
      let(:path) { "/user/runners?private_token=#{pat.token}" }
      let(:scope) { :create_runner }

      it_behaves_like 'creates a runner'

      context 'with read_api scope' do
        let(:scope) { :read_api }

        it 'fails with :forbidden code and does not log audit event' do
          expect do
            request

            expect(response).to have_gitlab_http_status(:forbidden)
          end.to not_change { Ci::Runner.count }
            .and not_change { AuditEvent.count }
        end
      end
    end
  end
end
