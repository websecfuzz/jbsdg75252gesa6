# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Search::Zoekt, :zoekt, :zoekt_settings_enabled, feature_category: :global_search do
  let(:admin) { create(:admin) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:unindexed_namespace) { create(:group) }
  let_it_be(:project) { create(:project) }
  let(:project_id) { project.id }
  let(:namespace_id) { namespace.id }
  let(:params) { {} }
  let(:node) { ::Search::Zoekt::Node.first }
  let(:node_id) { node.id }

  shared_examples 'an API that returns 400 when the application setting zoekt_indexing_enabled is disabled' do |verb|
    before do
      stub_ee_application_setting(zoekt_indexing_enabled: false)
    end

    it 'returns not_found status' do
      send(verb, api(path, admin, admin_mode: true))

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to eq('application setting zoekt_indexing_enabled is not enabled')
    end
  end

  shared_examples 'an API that returns 404 for missing ids' do |verb|
    it 'returns not_found status' do
      send(verb, api(path, admin, admin_mode: true))

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'an API that returns 401 for unauthenticated requests' do |verb|
    it 'returns not_found status' do
      send(verb, api(path, nil))

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  describe 'PUT /admin/zoekt/projects/:projects/index' do
    let(:path) { "/admin/zoekt/projects/#{project_id}/index" }

    it_behaves_like 'PUT request permissions for admin mode'
    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 400 when the application setting zoekt_indexing_enabled is disabled', :put

    it 'triggers indexing for the project' do
      expect(::Search::Zoekt).to receive(:index_async).with(project.id).and_return('the-job-id')

      put api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['job_id']).to eq('the-job-id')
    end

    it_behaves_like 'an API that returns 404 for missing ids', :put do
      let(:project_id) { non_existing_record_id }
    end
  end

  describe 'GET /admin/zoekt/shards' do
    let(:path) { '/admin/zoekt/shards' }
    let!(:another_node) do
      create(:zoekt_node, index_base_url: 'http://111.111.111.111/', search_base_url: 'http://111.111.111.112/')
    end

    it_behaves_like 'GET request permissions for admin mode'
    it_behaves_like 'an API that returns 401 for unauthenticated requests', :get

    it 'returns all nodes' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to match_array([
        hash_including(
          'id' => node.id,
          'index_base_url' => node.index_base_url,
          'search_base_url' => node.search_base_url
        ),
        hash_including(
          'id' => another_node.id,
          'index_base_url' => 'http://111.111.111.111/',
          'search_base_url' => 'http://111.111.111.112/'
        )
      ])
    end
  end

  describe 'GET /admin/zoekt/shards/:node_id/indexed_namespaces' do
    let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces" }

    let!(:enabled_namespace) do
      enabled_namespace = create(:zoekt_enabled_namespace, namespace: namespace)
      create(:zoekt_index, node: node, zoekt_enabled_namespace: enabled_namespace)

      enabled_namespace
    end

    let!(:another_node) do
      create(:zoekt_node, index_base_url: 'http://111.111.111.198/', search_base_url: 'http://111.111.111.199/')
    end

    let!(:enabled_namespace_for_another_node) do
      enabled_namespace_2 = create(:zoekt_enabled_namespace, namespace: create(:namespace))
      create(:zoekt_index, node: another_node, zoekt_enabled_namespace: enabled_namespace_2)

      enabled_namespace_2
    end

    let!(:another_enabled_namespace) do
      enabled_namespace_3 = create(:zoekt_enabled_namespace, namespace: create(:namespace))
      create(:zoekt_index, node: node, zoekt_enabled_namespace: enabled_namespace_3)

      enabled_namespace_3
    end

    it_behaves_like 'GET request permissions for admin mode'
    it_behaves_like 'an API that returns 401 for unauthenticated requests', :get

    it 'returns all indexed namespaces for this node' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to match_array([
        hash_including(
          'id' => enabled_namespace.id,
          'zoekt_shard_id' => node.id,
          'zoekt_node_id' => node.id,
          'namespace_id' => namespace.id
        ),
        hash_including(
          'id' => another_enabled_namespace.id,
          'zoekt_shard_id' => node.id,
          'zoekt_node_id' => node.id,
          'namespace_id' => another_enabled_namespace.namespace.id
        )
      ])
    end

    it 'returns at most MAX_RESULTS most recent rows' do
      stub_const("#{described_class}::MAX_RESULTS", 1)

      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to match_array([
        hash_including(
          'id' => another_enabled_namespace.id,
          'zoekt_shard_id' => node.id,
          'zoekt_node_id' => node.id,
          'namespace_id' => another_enabled_namespace.namespace.id
        )
      ])
    end

    it_behaves_like 'an API that returns 404 for missing ids', :get do
      let(:node_id) { non_existing_record_id }
    end
  end

  describe 'PUT /admin/zoekt/shards/:node_id/indexed_namespaces/:namespace_id' do
    let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}" }

    it_behaves_like 'PUT request permissions for admin mode'
    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 400 when the application setting zoekt_indexing_enabled is disabled', :put

    it 'creates ::Search::Zoekt::EnabledNamespace & ::Search::Zoekt::Index with search enabled for the namespace' do
      expect do
        put api(path, admin, admin_mode: true)
      end.to change { ::Search::Zoekt::EnabledNamespace.count }.from(0).to(1)
        .and change { ::Search::Zoekt::Index.count }.from(0).to(1)

      expect(response).to have_gitlab_http_status(:ok)
      np = ::Search::Zoekt::EnabledNamespace.find_by(namespace: namespace)
      expect(json_response['id']).to eq(np.id)
      expect(np.search).to eq(true)

      zoekt_index = ::Search::Zoekt::Index.find_by(zoekt_enabled_namespace_id: np.id)
      expect(json_response['zoekt_node_id']).to eq(zoekt_index.zoekt_node_id)
      expect(zoekt_index).to be_ready
    end

    context 'when search parameter is set to false' do
      let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}?search=false" }

      it 'creates ::Search::Zoekt::EnabledNamespace & ::Search::Zoekt::Index with search disabled for the namespace' do
        expect do
          put api(path, admin, admin_mode: true)
        end.to change { ::Search::Zoekt::EnabledNamespace.count }.from(0).to(1)
          .and change { ::Search::Zoekt::Index.count }.from(0).to(1)
          .and change { ::Search::Zoekt::Replica.where(namespace_id: namespace_id).count }.from(0).to(1)

        expect(response).to have_gitlab_http_status(:ok)
        np = ::Search::Zoekt::EnabledNamespace.find_by(namespace: namespace)
        expect(json_response['id']).to eq(np.id)
        expect(np.search).to eq(false)
      end
    end

    context 'when it already exists' do
      it 'returns the existing one' do
        id = create(:zoekt_enabled_namespace, namespace: namespace).id

        put api(path, admin, admin_mode: true)

        expect(json_response['id']).to eq(id)
      end

      context 'and search parameter is not present' do
        let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}" }

        it 'does not change the search attribute' do
          np = create(:zoekt_enabled_namespace, namespace: namespace, search: false)
          put api(path, admin, admin_mode: true)
          expect(json_response['id']).to eq(np.id)
          np.reload
          expect(np.search).to eq(false)
        end
      end

      context 'and search parameter is set to true' do
        let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}?search=true" }

        it 'changes the search attribute to true' do
          np = create(:zoekt_enabled_namespace, namespace: namespace, search: false)
          expect { put api(path, admin, admin_mode: true) }.to change { np.reload.search }.from(false).to(true)
          expect(json_response['id']).to eq(np.id)
        end
      end

      context 'and search parameter is set to false' do
        let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}?search=false" }

        it 'changes the search attribute to false' do
          np = create(:zoekt_enabled_namespace, namespace: namespace, search: true)
          expect { put api(path, admin, admin_mode: true) }.to change { np.reload.search }.from(true).to(false)
          expect(json_response['id']).to eq(np.id)
        end
      end
    end

    context 'with missing node_id' do
      it_behaves_like 'an API that returns 404 for missing ids', :put do
        let(:node_id) { non_existing_record_id }
      end
    end

    context 'when node_id is 0' do
      let(:node_id) { 0 }

      it 'creates only Search::Zoekt::EnabledNamespace with search enabled for the namespace' do
        expect { put api(path, admin, admin_mode: true) }
          .to change { Search::Zoekt::EnabledNamespace.count }.by(1)
          .and not_change { Search::Zoekt::Index.count }
        expect(response).to have_gitlab_http_status(:ok)
        np = Search::Zoekt::EnabledNamespace.find_by(namespace: namespace)
        expect(json_response['id']).to eq(np.id)
        expect(np.search).to eq(true)
        expect(json_response['zoekt_node_id']).to eq(nil)
      end
    end

    context 'with missing namespace_id' do
      it_behaves_like 'an API that returns 404 for missing ids', :put do
        let(:namespace_id) { non_existing_record_id }
      end
    end
  end

  describe 'DELETE /admin/zoekt/shards/:node_id/indexed_namespaces/:namespace_id' do
    let(:path) { "/admin/zoekt/shards/#{node_id}/indexed_namespaces/#{namespace_id}" }
    let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }

    before do
      create(:zoekt_index, node: node, zoekt_enabled_namespace: enabled_namespace, namespace_id: namespace.id)
    end

    it_behaves_like 'DELETE request permissions for admin mode'
    it_behaves_like 'an API that returns 401 for unauthenticated requests', :delete

    it 'removes the ::Search::Zoekt::Index and ::Search::Zoekt::EnabledNamespace for this node and namespace pair' do
      expect do
        delete api(path, admin, admin_mode: true)
      end.to change { ::Search::Zoekt::Index.count }.by(-1)
        .and change { ::Search::Zoekt::EnabledNamespace.count }.by(-1)

      expect(response).to have_gitlab_http_status(:no_content)
    end

    context 'when zoekt_enabled_namespace does not exist' do
      let(:namespace_id) { create(:namespace).id }

      it 'makes no changes to ::Search::Zoekt::Index' do
        expect do
          delete api(path, admin, admin_mode: true)
        end.not_to change { ::Search::Zoekt::Index.count }

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'with missing node_id' do
      it_behaves_like 'an API that returns 404 for missing ids', :delete do
        let(:node_id) { non_existing_record_id }
      end
    end

    context 'when node_id is 0' do
      let(:node_id) { 0 }

      before do
        node2 = create(:zoekt_node, search_base_url: node.search_base_url, index_base_url: node.index_base_url)
        create(:zoekt_index, node: node2, zoekt_enabled_namespace: enabled_namespace, namespace_id: namespace.id)
      end

      it 'removes Search::Zoekt::EnabledNamespace and all associated Search::Zoekt::Index records' do
        expect { delete api(path, admin, admin_mode: true) }
          .to change { Search::Zoekt::EnabledNamespace.count }.by(-1).and change { Search::Zoekt::Index.count }.by(-2)
        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'with missing namespace_id' do
      it_behaves_like 'an API that returns 404 for missing ids', :delete do
        let(:namespace_id) { non_existing_record_id }
      end
    end
  end
end
