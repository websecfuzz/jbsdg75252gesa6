# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::Registries, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  describe 'GET /api/v4/groups/:id/-/virtual_registries/packages/maven/registries' do
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/packages/maven/registries" }

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to contain_exactly(registry.as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid group_id' do
      it_behaves_like 'successful response'
    end

    context 'with invalid group_id' do
      where(:group_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :not_found
        ''                     | :not_found
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
        'PRIVATE'  | :not_found
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

  describe 'POST /api/v4/groups/:id/-/virtual_registries/packages/maven/registries' do
    let_it_be(:registry_class) { ::VirtualRegistries::Packages::Maven::Registry }
    let(:group_id) { group.id }
    let(:url) { "/groups/#{group_id}/-/virtual_registries/packages/maven/registries" }
    let(:params) { { name: 'foo' } }

    subject(:api_request) { post api(url), headers:, params: }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { registry_class.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(Gitlab::Json.parse(response.body)).to eq(registry_class.last.as_json)
      end
    end

    context 'with valid params' do
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
          registry_class.for_group(group).delete_all
          group.send(:"add_#{user_role}", user)
        end

        if params[:status] == :created
          it_behaves_like 'successful response'
        else
          it_behaves_like 'returning response status', params[:status]
        end
      end

      context 'with existing registry' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'successful response'
      end

      it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :created do
        before_all do
          group.add_maintainer(user)
        end

        before do
          registry_class.for_group(group).delete_all
        end
      end
    end

    context 'with invalid group_id' do
      before_all do
        group.add_maintainer(user)
      end

      where(:group_id, :status) do
        non_existing_record_id  | :not_found
        'foo'                   | :not_found
        ''                      | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with invalid params' do
      before_all do
        group.add_maintainer(user)
      end

      let(:params) { { name:, description: } }

      where(:name, :description, :status) do
        ''            | 'bar'          | :bad_request
        ('foo' * 256) | 'bar'          | :bad_request
        'foo'         | ('bar' * 1025) | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    context 'with subgroup' do
      let(:subgroup) { create(:group, parent: group, visibility_level: group.visibility_level) }

      let(:group_id) { subgroup.id }

      before_all do
        group.add_maintainer(user)
      end

      it 'returns a bad request because it is not a top level group' do
        api_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response).to eq({ 'message' => { 'group' => ['must be a top level Group'] } })
      end
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/registries/:id' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}" }
    let(:registry_as_json) do
      registry.as_json.merge(
        registry_upstreams: registry.registry_upstreams.map { |e| e.slice(:id, :upstream_id, :position) }
      ).as_json
    end

    subject(:api_request) { get api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)).to eq(registry_as_json)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid registry_id' do
      it_behaves_like 'successful response'
    end

    context 'with invalid registry_id' do
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

  describe 'PATCH /api/v4/virtual_registries/packages/maven/registries/:id' do
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry.id}" }

    subject(:api_request) { patch api(url), params:, headers: }

    context 'with valid params' do
      let(:params) { { name: 'foo', description: 'description' } }

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

      let(:params) { { name:, description: }.compact }

      where(:name, :description, :status) do
        nil   | 'bar' | :ok
        'foo' | nil   | :ok
        'foo' | 'bar' | :ok
        ''    | 'bar' | :bad_request
        'foo' | ''    | :bad_request
        nil   | nil   | :bad_request
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/registries/:id' do
    let(:registry_id) { registry.id }
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry_id}" }

    subject(:api_request) { delete api(url), headers: headers }

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change { ::VirtualRegistries::Packages::Maven::Registry.count }.by(-1)
      end
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'disabled maven_virtual_registry feature flag'
    it_behaves_like 'maven virtual registry disabled dependency proxy'
    it_behaves_like 'maven virtual registry not authenticated user'
    it_behaves_like 'maven virtual registry feature not licensed'

    context 'with valid registry_id' do
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

    context 'with invalid registry_id' do
      where(:registry_id, :status) do
        non_existing_record_id | :not_found
        'foo'                  | :bad_request
        ''                     | :not_found
      end

      with_them do
        it_behaves_like 'returning response status', params[:status]
      end
    end

    it_behaves_like 'an authenticated virtual registry REST API', with_successful_status: :no_content do
      before_all do
        group.add_maintainer(user)
      end
    end
  end

  describe 'DELETE /api/v4/virtual_registries/packages/maven/registries/:id/cache', :sidekiq_inline do
    let(:url) { "/virtual_registries/packages/maven/registries/#{registry.id}/cache" }

    subject(:api_request) { delete api(url), headers: headers }

    before_all do
      create_list(:virtual_registries_packages_maven_cache_entry, 2, upstream:) # 2 default
      create(:virtual_registries_packages_maven_cache_entry, :pending_destruction, upstream:) # 1 pending destruction
      create(:virtual_registries_packages_maven_cache_entry) # 1 default in another upstream
      create(:virtual_registries_packages_maven_registry).tap do |registry2|
        create(:virtual_registries_packages_maven_upstream, registries: [registry, registry2]).tap do |upstream2|
          create(:virtual_registries_packages_maven_cache_entry, upstream: upstream2) # 1 default in a shared upstream
        end
      end
    end

    shared_examples 'successful response' do
      it 'returns a successful response' do
        expect { api_request }.to change {
          ::VirtualRegistries::Packages::Maven::Cache::Entry.pending_destruction.count
        }.by(3) # 2 created in `before_all` + 1 from 'for maven virtual registry api setup' shared context

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
        :planner    | :forbidden
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
