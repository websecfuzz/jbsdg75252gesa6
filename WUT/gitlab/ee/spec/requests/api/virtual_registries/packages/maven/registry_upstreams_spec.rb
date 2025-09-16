# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::RegistryUpstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'POST /api/v4/virtual_registries/packages/maven/registry_upstreams' do
    let_it_be_with_refind(:upstream2) do
      create(:virtual_registries_packages_maven_upstream, group: group, registries: [])
    end

    let(:registry_id) { registry.id }
    let(:upstream_id) { upstream2.id }
    let(:url) { '/virtual_registries/packages/maven/registry_upstreams' }
    let(:params) { { registry_id:, upstream_id: } }

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:created)
        expect(Gitlab::Json.parse(response.body)).to eq(
          upstream2.registry_upstreams.last.as_json.except('group_id', 'created_at', 'updated_at')
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    where(:user_role, :status) do
      :owner      | :created
      :maintainer | :created
      :developer  | :forbidden
      :reporter   | :forbidden
      :guest      | :forbidden
    end

    with_them do
      before do
        group.send(:"add_#{user_role}", user)
      end

      if params[:status] == :created
        it_behaves_like 'successful response'
      else
        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'with invalid params' do
      where(:param_registry_id, :param_upstream_id, :status) do
        non_existing_record_id | non_existing_record_id | :not_found
        ref(:registry_id)      | non_existing_record_id | :not_found
        non_existing_record_id | ref(:upstream_id)      | :not_found
        'foo'                  | 'bar'                  | :bad_request
      end

      before_all do
        group.add_maintainer(user)
      end

      with_them do
        let(:params) { { registry_id: param_registry_id, upstream_id: param_upstream_id } }

        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'when upstream is already shared' do
      let(:params) { { registry_id: registry.id, upstream_id: upstream.id } }

      before_all do
        group.add_maintainer(user)
      end

      it 'returns a bad request' do
        api_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => { 'upstream_id' => ['has already been taken'] } })
      end
    end
  end

  describe 'PATCH /api/v4/virtual_registries/packages/maven/registry_upstreams/:id' do
    let(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }
    let(:url) { "/virtual_registries/packages/maven/registry_upstreams/#{registry_upstream.id}" }

    subject(:api_request) { patch api(url), headers: headers, params: params }

    context 'with valid params' do
      let(:params) { { position: 5 } }

      it { is_expected.to have_request_urgency(:low) }

      it_behaves_like 'disabled maven_virtual_registry feature flag'
      it_behaves_like 'maven virtual registry disabled dependency proxy'
      it_behaves_like 'maven virtual registry not authenticated user'
      it_behaves_like 'maven virtual registry feature not licensed'

      where(:user_role, :status) do
        :owner      | :ok
        :maintainer | :ok
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          group.send(:"add_#{user_role}", user)
        end

        it_behaves_like 'returning response status', params[:status]
      end

      it_behaves_like 'an authenticated virtual registry REST API' do
        before_all do
          group.add_maintainer(user)
        end
      end
    end

    context 'with invalid params' do
      [0, -1, 'a', 21].each do |position|
        context "when position is #{position}" do
          let(:params) { { position: position } }

          it 'returns a bad request' do
            api_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response).to match({ 'error' => /position does not have a valid value/ })
          end
        end
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/registry_upstreams/:id' do
    let(:registry_upstream) { upstream.registry_upstreams.first }
    let(:url) { "/virtual_registries/packages/maven/registry_upstreams/#{registry_upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response for orphan upstream' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    where(:user_role, :status) do
      :owner      | :no_content
      :maintainer | :no_content
      :developer  | :forbidden
      :reporter   | :forbidden
      :guest      | :forbidden
    end

    with_them do
      before do
        group.send(:"add_#{user_role}", user)
      end

      if params[:status] == :no_content
        it_behaves_like 'successful response for orphan upstream'
      else
        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end

    context 'when upstream is shared between registries' do
      let_it_be(:registry_2) { create(:virtual_registries_packages_maven_registry, group: group, name: 'other') }
      let_it_be(:registry_upstream_2) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }
      let_it_be(:registry_upstream_3) do
        create(:virtual_registries_packages_maven_registry_upstream, upstream: registry_upstream_2.upstream,
          registry: registry_2)
      end

      let(:registry_upstream) { registry_upstream_3 }

      before_all do
        group.add_maintainer(user)
      end

      it 'deletes the registry upstream but keeps the upstream' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
          .and not_change { ::VirtualRegistries::Packages::Maven::Upstream.count }
      end
    end

    context 'for position sync' do
      let_it_be_with_refind(:upstream_2) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

      before_all do
        group.add_maintainer(user)
      end

      it 'syncs the position' do
        expect { api_request }.to change { upstream_2.registry_upstreams.take.position }.by(-1)
      end
    end
  end
end
