# frozen_string_literal: true

module EE
  module Repositories
    module GitHttpController
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      override :render_ok
      def render_ok
        set_workhorse_internal_api_content_type

        render json: ::Gitlab::Workhorse.git_http_ok(repository, repo_type, user, action_name, show_all_refs: geo_request?, need_audit: need_git_audit_event?)
      end

      override :info_refs
      def info_refs
        track_git_ops_event_if_from_secondary(params["geo_node_id"])

        super
      end

      # This is reached on a primary for a request originating on a secondary
      # only when the repository on the secondary is out of date with that on
      # the primary
      override :git_upload_pack
      def git_upload_pack
        track_git_ops_event_if_from_secondary(params["geo_node_id"])

        super
      end

      # This is reached on a primary for a request originating on a secondary
      # only when the repository on the secondary is out of date with that on
      # the primary
      override :ssh_upload_pack
      def ssh_upload_pack
        if geo?
          set_workhorse_internal_api_content_type

          render json: ::Gitlab::Workhorse.git_http_ok(repository, repo_type, user, :git_upload_pack, show_all_refs: geo_request?, need_audit: need_git_audit_event?)
        else
          super
        end
      end

      # This is reached on a primary for a request originating on a secondary
      # only when the repository on the secondary is out of date with that on
      # the primary
      override :ssh_receive_pack
      def ssh_receive_pack
        return super unless geo?

        raise ::Gitlab::GitAccess::ForbiddenError, 'Cannot push to secondary.' unless ::Gitlab::Geo.primary?

        set_workhorse_internal_api_content_type

        render json: ::Gitlab::Workhorse.git_http_ok(repository, repo_type, user, :git_receive_pack, show_all_refs: geo_request?, need_audit: need_git_audit_event?)
      end

      # Git push over HTTP
      override :git_receive_pack
      def git_receive_pack
        # Authentication/authorization already happened in `before_action`s

        if ::Gitlab::Geo.primary?
          # This ID is used by the /internal/post_receive API call
          gl_id = ::Gitlab::GlId.gl_id(user)
          gl_repository = repo_type.identifier_for_container(container)
          node_id = params["geo_node_id"]

          track_git_ops_event_if_from_secondary(node_id)

          ::Gitlab::Geo::GitPushHttp.new(gl_id, gl_repository).cache_referrer_node(node_id)
        end

        super
      end

      private

      override :user
      def user
        super || (geo_push_user&.deploy_key&.user || geo_push_user&.user)
      end

      def geo_push_user
        return unless geo_gl_id

        @geo_push_user ||= ::Geo::PushUser.new(geo_gl_id) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end

      def geo_gl_id
        decoded_authorization&.dig(:gl_id)
      end

      def geo_push_proxy_request?
        geo_gl_id
      end

      def geo_request?
        ::Gitlab::Geo::JwtRequestDecoder.geo_auth_attempt?(request.headers['Authorization'])
      end

      def geo?
        authentication_result.geo?
      end

      def need_git_audit_event?
        ::Gitlab::GitAuditEvent.new(user, project).enabled?
      end

      override :access_actor
      def access_actor
        return super unless geo?
        return :geo unless geo_push_proxy_request?

        # A deploy key access actor must be extracted before checking git access.
        # This is necessary for proxied requests from secondary sites.
        actor = geo_push_user.deploy_key || geo_push_user.user
        return actor if actor

        raise ::Gitlab::GitAccess::ForbiddenError, 'Geo push user is invalid.'
      end

      override :authenticate_user
      def authenticate_user
        return super unless geo_request?
        return render_bad_geo_response('Request from this IP is not allowed') unless ip_allowed?
        return render_bad_geo_jwt('Bad token') unless decoded_authorization
        return render_bad_geo_jwt('Unauthorized scope') unless jwt_scope_valid?

        # Grant access
        @authentication_result = ::Gitlab::Auth::Result.new(nil, project, :geo, [:download_code, :push_code]) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      rescue ::Gitlab::Geo::InvalidDecryptionKeyError
        render_bad_geo_jwt("Invalid decryption key")
      rescue ::Gitlab::Geo::InvalidSignatureTimeError
        render_bad_geo_jwt("Invalid signature time ")
      end

      override :update_fetch_statistics
      def update_fetch_statistics
        send_git_audit_streaming_event unless ::Feature.enabled?(:log_git_streaming_audit_events, project)
        super
      end

      def jwt_scope_valid?
        decoded_authorization[:scope] == repository_path.delete_suffix('.git')
      end

      def decoded_authorization
        strong_memoize(:decoded_authorization) do
          ::Gitlab::Geo::JwtRequestDecoder.new(request.headers['Authorization']).decode
        end
      end

      def render_bad_geo_jwt(message)
        render_bad_geo_response("Geo JWT authentication failed: #{message}")
      end

      def render_bad_geo_response(message)
        render plain: message, status: :unauthorized
      end

      def ip_allowed?
        ::Gitlab::Geo.allowed_ip?(request.ip)
      end

      def send_git_audit_streaming_event
        ::Gitlab::GitAuditEvent.new(user, project).send_audit_event({ protocol: 'http', action: 'git-upload-pack' })
      end

      # Track a git operation event if this request originated on a Geo secondary
      # and was redirected/proxied to the primary.
      #
      # `git push` over ssh and http is tracked here.
      # `git pull` is tracked in the case where the repo on the secondary was
      # out-of-date and had to be pulled from the primary.
      def track_git_ops_event_if_from_secondary(node_id)
        return unless track_git_op_event?(node_id)

        ::Gitlab::InternalEvents.track_event(
          "geo_secondary_git_op_action",
          user: user,
          project: project,
          namespace: project&.namespace
        )
      end

      def track_git_op_event?(node_id)
        # Don't track git operations by CI
        return if ci?

        # Only track on primary
        return unless node_id && ::Gitlab::Geo.primary?

        # Don't track if the request originated on the primary itself
        return if node_id.to_i == ::Gitlab::Geo.current_node.id

        # Only track when the user is identified, since we are only interested
        # in unique users performing git operations
        user.is_a?(User)
      end
    end
  end
end
