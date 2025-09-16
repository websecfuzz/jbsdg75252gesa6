# frozen_string_literal: true

module API
  module VirtualRegistries
    module Packages
      module Maven
        class Endpoints < ::API::Base
          include ::API::Concerns::VirtualRegistries::Packages::Maven::SharedSetup
          include ::API::Concerns::VirtualRegistries::Packages::Endpoint
          include ::API::APIGuard

          AUTHENTICATE_REALM_HEADER = 'WWW-Authenticate'
          AUTHENTICATE_REALM_NAME = 'Basic realm="GitLab Virtual Registry"'

          SHA1_CHECKSUM_HEADER = 'x-checksum-sha1'
          MD5_CHECKSUM_HEADER = 'x-checksum-md5'

          authenticate_with do |accept|
            accept.token_types(:personal_access_token).sent_through(:http_private_token_header)
            accept.token_types(:deploy_token).sent_through(:http_deploy_token_header)
            accept.token_types(:job_token).sent_through(:http_job_token_header)

            accept.token_types(
              :personal_access_token_with_username,
              :deploy_token_with_username,
              :job_token_with_username
            ).sent_through(:http_basic_auth)
          end

          allow_access_with_scope :read_virtual_registry

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            delegate :group, to: :registry
            alias_method :target_group, :group

            def registry
              ::VirtualRegistries::Packages::Maven::Registry.find(params[:id])
            end
            strong_memoize_attr :registry

            def download_file_extra_response_headers(action_params:)
              {
                SHA1_CHECKSUM_HEADER => action_params[:file_sha1],
                MD5_CHECKSUM_HEADER => action_params[:file_md5]
              }
            end

            # override from api helpers unauthorized! function
            def unauthorized!(reason = nil)
              header(AUTHENTICATE_REALM_HEADER, AUTHENTICATE_REALM_NAME)
              super
            end

            params :id_and_path do
              requires :id,
                type: Integer,
                desc: 'The ID of the Maven virtual registry'
              requires :path,
                type: String,
                file_path: true,
                desc: 'Package path',
                documentation: { example: 'foo/bar/mypkg/1.0-SNAPSHOT/mypkg-1.0-SNAPSHOT.jar' }
            end
          end

          namespace 'virtual_registries/packages/maven/:id/*path' do
            desc 'Download endpoint of the Maven virtual registry.' do
              detail 'This feature was introduced in GitLab 17.3. \
                      This feature is currently in experiment state. \
                      This feature is behind the `maven_virtual_registry` feature flag.'
              success [
                { code: 200 }
              ]
              failure [
                { code: 400, message: 'Bad request' },
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not Found' }
              ]
              tags %w[maven_virtual_registries]
              hidden true
            end
            params do
              use :id_and_path
            end
            get format: false do
              service_response = ::VirtualRegistries::Packages::Maven::HandleFileRequestService.new(
                registry: registry,
                current_user: current_user,
                params: { path: declared_params[:path] }
              ).execute

              send_error_response_from!(service_response: service_response) if service_response.error?
              send_successful_response_from(service_response: service_response)
            end

            desc 'Workhorse upload endpoint of the Maven virtual registry. Only workhorse can access it.' do
              detail 'This feature was introduced in GitLab 17.4. \
                      This feature is currently in experiment state. \
                      This feature is behind the `maven_virtual_registry` feature flag.'
              success [
                { code: 200 }
              ]
              failure [
                { code: 400, message: 'Bad request' },
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not Found' }
              ]
              tags %w[maven_virtual_registries]
              hidden true
            end
            params do
              use :id_and_path
              requires :file,
                type: ::API::Validations::Types::WorkhorseFile,
                desc: 'The file being uploaded',
                documentation: { type: 'file' }
            end
            post 'upload' do
              require_gitlab_workhorse!
              authorize!(:read_virtual_registry, registry)

              etag, content_type, upstream_gid = headers.fetch_values(
                'Etag',
                ::Gitlab::Workhorse::SEND_DEPENDENCY_CONTENT_TYPE_HEADER,
                UPSTREAM_GID_HEADER
              ) { nil }

              target_upstream = GlobalID::Locator.locate(upstream_gid)
              not_found!('Upstream') unless registry.upstreams.include?(target_upstream)

              service_response = ::VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService.new(
                upstream: target_upstream,
                current_user: current_user,
                params: declared_params.merge(etag: etag, content_type: content_type)
              ).execute

              send_error_response_from!(service_response: service_response) if service_response.error?
              ok_empty_response
            end
          end
        end
      end
    end
  end
end
