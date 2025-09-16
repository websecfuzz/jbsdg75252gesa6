# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::Upstreams, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'GET /api/v4/virtual_registries/packages/maven/registries/:id/upstreams' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}/upstreams" }
    let(:upstream_as_json) do
      upstream.as_json.merge(
        registry_upstream: upstream.registry_upstreams.take.slice(:id, :registry_id, :position)
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to contain_exactly(upstream_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid registry' do
      it_behaves_like 'successful response'
    end

    context 'with invalid registry' do
      where(:registry_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :bad_request
        ''                     | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with a non member user' do
      let_it_be(:user) { create(:user) }

      where(:group_access_level, :status) do
        'PUBLIC'   | :forbidden
        'INTERNAL' | :forbidden
        'PRIVATE'  | :forbidden
      end

      with_them do
        before do
          group.update!(visibility_level: Gitlab::VisibilityLevel.const_get(group_access_level, false))
        end

        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API'
  end

  describe 'POST /api/v4/virtual_registries/packages/maven/registries/:id/upstreams' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}/upstreams" }
    let(:params) { { url: 'http://example.com', name: 'foo', username: 'user', password: 'test' } }
    let(:upstream_as_json) do
      upstream_model.last.as_json.merge(
        registry_upstream: upstream_model.last.registry_upstreams.take.slice(:id, :registry_id, :position)
      ).as_json
    end

    subject(:api_request) { post api(url), headers: headers, params: params }

    shared_examples 'successful response' do
      let(:upstream_model) { ::VirtualRegistries::Packages::Maven::Upstream }

      it 'returns a successful response' do
        expect { api_request }.to change { upstream_model.count }.by(1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(Gitlab::Json.parse(response.body)).to eq(upstream_as_json)
        expect(upstream_model.last.cache_validity_hours).to eq(
          params[:cache_validity_hours] || upstream_model.new.cache_validity_hours
        )
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid params' do
      where(:user_role, :status) do
        :owner      | :created
        :maintainer | :created
        :developer  | :forbidden
        :reporter   | :forbidden
        :guest      | :forbidden
      end

      with_them do
        before do
          registry.upstreams.each(&:destroy!)
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    context 'with invalid registry' do
      where(:registry_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :bad_request
        ''                     | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'for params' do
      # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
      where(:params, :status) do
        { name: 'foo', description: 'bar', url: 'http://example.com', username: 'test', password: 'test', cache_validity_hours: 3 } | :created
        { name: 'foo', url: 'http://example.com', username: 'test', password: 'test' }                                              | :created
        { url: '', username: 'test', password: 'test' }                                                                             | :bad_request
        { url: 'http://example.com', username: 'test' }                                                                             | :bad_request
        {}                                                                                                                          | :bad_request
      end
      # rubocop:enable Layout/LineLength

      before do
        registry.upstreams.each(&:destroy!)
      end

      before_all do
        group.add_maintainer(user)
      end

      with_them do
        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    context 'with a full registry' do
      before_all do
        group.add_maintainer(user)
        registry.upstreams.delete_all
        build_list(
          :virtual_registries_packages_maven_registry_upstream,
          VirtualRegistries::Packages::Maven::RegistryUpstream::MAX_UPSTREAMS_COUNT,
          registry:
        ).each(&:save!)
      end

      it_behaves_like 'returning response status with message',
        status: :bad_request,
        message: { 'registry_upstreams.position' => ['must be less than or equal to 20'] }
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created do
      before_all do
        group.add_maintainer(user)
      end

      before do
        registry.upstreams.each(&:destroy!)
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }
    let(:upstream_as_json) do
      upstream.as_json.merge(
        registry_upstreams: upstream.registry_upstreams.map { |e| e.slice(:id, :registry_id, :position) }
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to eq(upstream_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid params' do
      it_behaves_like 'successful response'
    end

    context 'with a non member user' do
      let_it_be(:user) { create(:user) }

      where(:group_access_level, :status) do
        'PUBLIC'   | :forbidden
        'INTERNAL' | :forbidden
        'PRIVATE'  | :forbidden
      end

      with_them do
        before do
          group.update!(visibility_level: Gitlab::VisibilityLevel.const_get(group_access_level, false))
        end

        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API'
  end

  describe 'PATCH /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }

    subject(:api_request) { patch api(url), params: params, headers: headers }

    context 'with valid params' do
      let(:params) { { name: 'foo', description: 'description', url: 'http://example.com', username: 'test', password: 'test' } }

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

    context 'for params' do
      before_all do
        group.add_maintainer(user)
      end

      let(:params) do
        { name: name, description: description, url: param_url, username: username, password: password,
          cache_validity_hours: cache_validity_hours }.compact
      end

      where(:name, :description, :param_url, :username, :password, :cache_validity_hours, :status) do
        nil   | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :ok
        'foo' | nil   | 'http://example.com' | 'test' | 'test' | 3   | :ok
        'foo' | 'bar' | nil                  | 'test' | 'test' | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | nil    | 'test' | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | nil    | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | nil | :ok
        nil   | nil   | nil                  | nil    | nil    | 3   | :ok
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :ok
        'foo' | ''    | 'http://example.com' | 'test' | 'test' | 3   | :ok
        ''    | 'bar' | 'http://example.com' | 'test' | 'test' | 3   | :bad_request
        'foo' | 'bar' | ''                   | 'test' | 'test' | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | ''     | 'test' | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | ''     | 3   | :bad_request
        'foo' | 'bar' | 'http://example.com' | 'test' | 'test' | -1  | :bad_request
        nil   | nil   | nil                  | nil    | nil    | nil | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/upstreams/:id' do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
          .and change { ::VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'for different user roles' do
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
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
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

  describe 'DELETE /api/v4/virtual_registries/packages/maven/upstreams/:id/cache', :sidekiq_inline do
    let(:url) { "/virtual_registries/packages/maven/upstreams/#{upstream.id}/cache" }

    subject(:api_request) { delete api(url), headers: headers }

    before_all do
      create_list(:virtual_registries_packages_maven_cache_entry, 2, upstream:) # 2 default
      create(:virtual_registries_packages_maven_cache_entry, :pending_destruction, upstream:) # 1 pending destruction
      create(:virtual_registries_packages_maven_cache_entry) # 1 default in another upstream
    end

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          ::VirtualRegistries::Packages::Maven::Cache::Entry.pending_destruction.count
        }.by(3) # 2 created in before_all + 1 from 'for maven virtual registry api setup' shared context

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'for different user roles' do
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
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end
  end
end
