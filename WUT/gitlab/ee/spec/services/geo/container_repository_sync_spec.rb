# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ContainerRepositorySync, :geo, feature_category: :geo_replication do
  let_it_be(:group) { create(:group, name: 'group') }
  let_it_be(:project) { create(:project, path: 'test', group: group) }

  let(:container_repository) { create(:container_repository, name: 'my_image', project: project) }
  let(:primary_api_url) { 'http://primary.registry.gitlab' }
  let(:secondary_api_url) { 'http://secondary.registry.gitlab' }
  let(:primary_repository_url) { "#{primary_api_url}/v2/#{container_repository.path}" }
  let(:secondary_repository_url) { "#{secondary_api_url}/v2/#{container_repository.path}" }

  # Break symbol will be removed if JSON encode/decode operation happens so we use this
  # to prove that it does not happen and we preserve original human readable JSON
  let(:manifest) do
    "{" \
      "\n\"schemaVersion\":2," \
      "\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\"," \
      "\n\"layers\":[" \
        "{\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\",\n\"size\":3333,\n\"digest\":\"sha256:3333\"}," \
        "{\n\"mediaType\":\"application/vnd.docker.distribution.manifest.v2+json\",\n\"size\":4444,\n\"digest\":\"sha256:4444\"}," \
        "{\n\"mediaType\":\"application/vnd.docker.image.rootfs.foreign.diff.tar.gzip\",\n\"size\":5555,\n\"digest\":\"sha256:5555\",\n\"urls\":[\"https://foo.bar/v2/zoo/blobs/sha256:5555\"]}" \
      "]" \
    "}"
  end

  let(:manifest_list) do
    %(
      {
        "schemaVersion":2,
        "mediaType":"application/vnd.docker.distribution.manifest.list.v2+json",
        "manifests":[
          {
            "mediaType":"application/vnd.docker.distribution.manifest.v2+json",
            "size":6666,
            "digest":"sha256:6666",
            "platform":
              {
                "architecture":"arm64","os":"linux"
              }
          }
        ]
      }
    )
  end

  before do
    stub_container_registry_config(enabled: true, api_url: secondary_api_url)
    stub_registry_replication_config(enabled: true, primary_api_url: primary_api_url)
    stub_connected(true)
  end

  shared_context 'with the Gitlab API returning tags' do
    before do
      allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(true)
      allow(container_repository).to receive(:each_tags_page).and_call_original
      allow(container_repository.gitlab_api_client).to receive(:tags).and_return(
        { response_body: ::Gitlab::Json.parse(response_body) }
      )
    end
  end

  def stub_repository_tags_requests(repository_url, tags)
    stub_request(:get, "#{repository_url}/tags/list?n=#{::ContainerRegistry::Client::DEFAULT_TAGS_PAGE_SIZE}")
      .to_return(
        status: 200,
        body: Gitlab::Json.dump(tags: tags.keys),
        headers: { 'Content-Type' => 'application/json' })

    tags.each do |tag, digest|
      stub_request(:head, "#{repository_url}/manifests/#{tag}")
        .to_return(status: 200, body: "", headers: { DependencyProxy::Manifest::DIGEST_HEADER => digest })
    end
  end

  def stub_raw_manifest_request(repository_url, tag, manifest)
    stub_request(:get, "#{repository_url}/manifests/#{tag}")
      .to_return(status: 200, body: manifest, headers: {})
  end

  def stub_raw_manifest_list_request(repository_url, tag, manifest_list)
    stub_request(:get, "#{repository_url}/manifests/#{tag}")
      .to_return(status: 200, body: manifest_list, headers: {})
  end

  def stub_push_manifest_request(repository_url, tag, manifest)
    stub_request(:put, "#{repository_url}/manifests/#{tag}")
      .with(body: manifest)
      .to_return(status: 200, body: "", headers: {})
  end

  def stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, blobs)
    blobs.each do |digest, missing|
      stub_request(:head, "#{secondary_repository_url}/blobs/#{digest}")
        .to_return(status: (missing ? 404 : 200), body: "", headers: {})

      next unless missing

      stub_request(:get, "#{primary_repository_url}/blobs/#{digest}")
        .to_return(status: 200, body: File.new(Rails.root.join('ee/spec/fixtures/ee_sample_schema.json')), headers: {})
    end
  end

  def stub_connected(connected)
    allow_next_instance_of(ContainerRegistry::Client) do |client|
      allow(client).to receive(:connected?).and_return(connected)
    end
  end

  describe '#execute' do
    subject { described_class.new(container_repository) }

    context 'single manifest' do
      before do
        stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
        stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', manifest)
        stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })
        stub_push_manifest_request(secondary_repository_url, 'tag-to-sync', manifest)
      end

      shared_examples 'determining the list of tags to sync and to remove correctly' do
        it 'determines list of tags to sync and to remove correctly' do
          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).not_to receive(:push_blob).with('sha256:4444', anything, anything)
          expect(container_repository).not_to receive(:push_blob).with('sha256:5555', anything, anything)
          expect(container_repository).to receive(:delete_tag).with('sha256:2222')

          subject.execute
        end
      end

      shared_examples 'removing secondary tags without failure when primary repository does not have tags' do
        it 'removes secondary tags and does not fail' do
          stub_repository_tags_requests(primary_repository_url, {})
          expect(container_repository).to receive(:delete_tag).with('sha256:2222')
          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, { 'tag-to-remove' => 'sha256:2222' })
        end

        it_behaves_like 'determining the list of tags to sync and to remove correctly'
        it_behaves_like 'removing secondary tags without failure when primary repository does not have tags'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { [{ name: 'tag-to-remove', digest: 'sha256:2222' }].to_json }

        it_behaves_like 'determining the list of tags to sync and to remove correctly'
        it_behaves_like 'removing secondary tags without failure when primary repository does not have tags'
      end
    end

    context 'manifest list' do
      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:6666', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'image without mediaType parameter' do
      let(:manifest_no_media_type) do
        %(
          {
            "schemaVersion":2,
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"}
            ]
         }
        )
      end

      shared_examples 'pushing the correct blobs and manifests without failure' do
        it 'pushes the correct blobs and manifests without failure' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_request(primary_repository_url, 'tag-to-sync', manifest_no_media_type)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true })
          stub_push_manifest_request(secondary_repository_url, 'tag-to-sync', manifest_no_media_type)

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests without failure'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests without failure'
      end
    end

    context 'oci manifest list' do
      let(:oci_manifest) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.manifest.v1+json",
            "layers":[
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":3333,"digest":"sha256:3333"},
              {"mediaType":"application/vnd.oci.image.layer.v1.tar+gzip","size":4444,"digest":"sha256:4444"},
              {"mediaType":"application/vnd.docker.image.rootfs.foreign.diff.tar.gzip","size":5555,"digest":"sha256:5555","urls":["https://foo.bar/v2/zoo/blobs/sha256:5555"]}
            ]
         }
        )
      end

      let(:oci_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.manifest.v1+json",
                "size":6666,
                "digest":"sha256:6666",
                "platform":
                  {
                    "architecture":"arm64","os":"linux"
                  }
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', oci_manifest_list)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6666', oci_manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:6666', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'buildkit cache images' do
      let(:buildcache_manifest_list) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType":"application/vnd.oci.image.layer.v1.tar+gzip",
                "digest":"sha256:3333",
                "size":24803024,
                "annotations":{
                   "buildkit/createdat":"2022-06-17T16:44:22.638028085Z",
                   "containerd.io/uncompressed":"sha256:65feea9638f81cb1fab4ede714f970bb8453cd1a2aa23860d2bb3fdcb960068b"
                }
              },
              {
                "mediaType":"application/vnd.buildkit.cacheconfig.v0",
                "digest":"sha256:4444",
                "size":1753
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', buildcache_manifest_list)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:3333' => true, 'sha256:4444' => false })

          expect(container_repository).to receive(:push_blob).with('sha256:3333', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end
    end

    context 'OCI image with artifact' do
      let(:artifact_manifest) do
        %(
          {
            "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
            "artifactType": "application/vnd.example.sbom.v1",
            "blobs": [
              {
                "mediaType": "application/gzip",
                "size": 123,
                "digest": "sha256:8792"
              }
            ],
            "subject": {
              "mediaType": "application/vnd.oci.image.manifest.v1+json",
              "size": 1234,
              "digest": "sha256:cc06a2839488b8bd2a2b99dcdc03d5cfd818eed72ad08ef3cc197aac64c0d0a0"
            },
            "annotations": {
              "org.opencontainers.artifact.created": "2022-01-01T14:42:55Z",
              "org.example.sbom.format": "json"
            }
          }
        )
      end

      let(:manifest_list_with_artifacts) do
        %(
          {
            "schemaVersion":2,
            "mediaType":"application/vnd.oci.image.index.v1+json",
            "manifests":[
              {
                "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
                "size": 7682,
                "digest": "sha256:6015",
                "artifactType": "application/example",
                "annotations": {
                    "com.example.artifactKey1": "value1",
                    "com.example.artifactKey2": "value2"
                  }
              }
            ]
          }
        )
      end

      shared_examples 'pushing the correct blobs and manifests' do
        it 'pushes the correct blobs and manifests' do
          stub_repository_tags_requests(primary_repository_url, { 'tag-to-sync' => 'sha256:1111' })
          stub_raw_manifest_list_request(primary_repository_url, 'tag-to-sync', manifest_list_with_artifacts)
          stub_raw_manifest_request(primary_repository_url, 'sha256:6015', artifact_manifest)
          stub_missing_blobs_requests(primary_repository_url, secondary_repository_url, { 'sha256:8792' => true })

          expect(container_repository).to receive(:push_blob).with('sha256:8792', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('sha256:6015', anything, anything)
          expect(container_repository).to receive(:push_manifest).with('tag-to-sync', anything, anything)

          subject.execute
        end
      end

      context 'when the GitLab API is not supported' do
        before do
          allow(container_repository.gitlab_api_client).to receive(:supports_gitlab_api?).and_return(false)
          stub_repository_tags_requests(secondary_repository_url, {})
        end

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      context 'when the GitLab API is supported' do
        include_context 'with the Gitlab API returning tags'
        let(:response_body) { {} }

        it_behaves_like 'pushing the correct blobs and manifests'
      end

      it 'raises an error with a bad connection' do
        stub_connected(false)
        expect { subject.execute }.to raise_error.with_message('No valid connection to primary registry')
      end
    end

    describe '#client' do
      it 'caches the client' do
        client = subject.send(:client)
        client1 = subject.send(:client)
        client2 = nil

        travel_to(Time.current + Gitlab::CurrentSettings.container_registry_token_expire_delay.minutes) do
          client2 = subject.send(:client)
        end

        expect(client1.object_id).to be(client.object_id)
        expect(client2.object_id).not_to be(client.object_id)
      end
    end

    context 'when tag sync fails' do
      let(:tag) { { name: 'latest', digest: 'sha256:123' } }

      before do
        client = subject.send(:client)
        allow(client).to receive(:connected?).and_return(true)
        allow(subject).to receive(:tags_to_sync).and_return([tag])
        allow(subject).to receive(:tags_to_remove).and_return([])
        allow(subject).to receive(:sync_tag).with(tag).and_raise(StandardError.new("Sync failed"))
      end

      it 'logs the error and continues execution', :aggregate_failures do
        expect(subject).to receive(:log_error).with("Error while syncing tag latest: Sync failed")

        result = subject.execute

        expect(result).to be true
      end

      it 'logs multiple errors if multiple tags fail', :aggregate_failures do
        multiple_tags = [
          { name: 'latest', digest: 'sha256:123' },
          { name: 'v1.0', digest: 'sha256:456' }
        ]

        allow(subject).to receive(:tags_to_sync).and_return(multiple_tags)
        allow(subject).to receive(:sync_tag).and_raise(StandardError.new("Sync failed"))

        multiple_tags.each do |tag|
          expect(subject).to receive(:log_error).with("Error while syncing tag #{tag[:name]}: Sync failed")
        end

        expect { subject.execute }.not_to raise_error
      end
    end

    context 'when tag removal fails' do
      let(:tag) { { name: 'latest', digest: 'sha256:123' } }

      before do
        client = subject.send(:client)
        allow(client).to receive(:connected?).and_return(true)
        allow(subject).to receive(:tags_to_sync).and_return([])
        allow(subject).to receive(:tags_to_remove).and_return([tag])

        # Simulate the error during tag removal
        allow(container_repository).to receive(:delete_tag)
          .with(tag[:digest])
          .and_raise(StandardError.new("Failed to remove tag"))
      end

      it 'logs the error message', :aggregate_failures do
        expect(subject).to receive(:log_error)
          .with("Error while removing tag latest: Failed to remove tag")

        expect(subject.execute).to be true
      end

      it 'continues execution after logging the error' do
        expect { subject.execute }.not_to raise_error
      end

      it 'processes all tags in tags_to_remove even if one fails' do
        another_tag = { name: 'v1.0', digest: 'sha256:456' }
        allow(subject).to receive(:tags_to_remove).and_return([tag, another_tag])

        allow(container_repository).to receive(:delete_tag)
          .with(tag[:digest])
          .and_raise(StandardError.new("Failed to remove tag"))
        allow(container_repository).to receive(:delete_tag)
          .with(another_tag[:digest])
          .and_return(true)

        expect(container_repository).to receive(:delete_tag).twice
        expect(subject).to receive(:log_error).once

        subject.execute
      end
    end
  end
end
