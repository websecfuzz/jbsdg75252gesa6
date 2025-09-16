# frozen_string_literal: true

module EE
  module API
    module Helpers
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      def require_node_to_be_enabled!
        forbidden! 'Geo node is disabled.' unless ::Gitlab::Geo.current_node&.enabled?
      end

      def gitlab_geo_node_token?
        headers['Authorization']&.start_with?(::Gitlab::Geo::BaseRequest::GITLAB_GEO_AUTH_TOKEN_TYPE)
      end

      def authenticate_by_gitlab_geo_node_token!
        unauthorized! unless authorization_header_valid?
      rescue ::Gitlab::Geo::InvalidDecryptionKeyError, ::Gitlab::Geo::InvalidSignatureTimeError => e
        render_api_error!(e.to_s, 401)
      end

      def geo_jwt_decoder
        return unless gitlab_geo_node_token?

        strong_memoize(:geo_jwt_decoder) do
          ::Gitlab::Geo::JwtRequestDecoder.new(headers['Authorization'])
        end
      end

      # Update the jwt_decoder to allow authorization of disabled (paused) nodes
      def allow_paused_nodes!
        geo_jwt_decoder.include_disabled!
      end

      def check_gitlab_geo_request_ip!
        unauthorized! unless ::Gitlab::Geo.allowed_ip?(request.ip)
      end

      def authorization_header_valid?
        return unless gitlab_geo_node_token?

        scope = geo_jwt_decoder.decode.try { |x| x[:scope] }
        scope == ::Gitlab::Geo::API_SCOPE
      end

      def check_project_feature_available!(feature)
        not_found! unless user_project.feature_available?(feature)
      end

      def authorize_change_param(subject, *keys)
        keys.each do |key|
          authorize!(:"change_#{key}", subject) if params.has_key?(key)
        end
      end

      # Normally, only admin users should have access to see LDAP
      # groups. However, due to the "Allow group owners to manage LDAP-related
      # group settings" setting, any group owner can sync LDAP groups with
      # their project.
      #
      # In the future, we should also check that the user has access to manage
      # a specific group so that we can use the Ability class.
      def authenticated_with_ldap_admin_access!
        authenticate!

        forbidden! unless current_user.admin? ||
          ::Gitlab::CurrentSettings.current_application_settings
            .allow_group_owners_to_manage_ldap
      end

      override :read_project_ability
      def read_project_ability
        # CI job token authentication:
        # this method grants limited privileged for admin users
        # admin users can only access project if they are direct member
        job_token_authentication? ? :build_read_project : super
      end

      override :find_group!
      def find_group!(id, organization: nil)
        # CI job token authentication:
        # currently we do not allow any group access for CI job token
        if job_token_authentication?
          not_found!('Group')
        else
          super
        end
      end

      override :find_pipeline!
      def find_pipeline!(id)
        if job_token_authentication?
          not_found!('Pipeline')
        else
          super
        end
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def find_group_epic(iid)
        EpicsFinder.new(current_user, group_id: user_group.id).find_by!(iid: iid)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def find_or_create_subscription_add_on!(name, namespace = nil)
        not_found!('Subscription Add-on') unless GitlabSubscriptions::AddOn.names[name]

        GitlabSubscriptions::AddOn.find_or_create_by_name(name, namespace)
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def find_subscription_add_on_purchase!(namespace, add_on)
        GitlabSubscriptions::AddOnPurchase.find_by!(
          namespace: namespace,
          add_on: add_on
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def user_pipeline
        @pipeline ||= find_pipeline!(params[:id])
      end

      private

      override :project_finder_params_ee
      def project_finder_params_ee
        finder_params = {}

        finder_params[:include_hidden] = declared_params[:include_hidden] if declared_params[:include_hidden]
        finder_params[:with_security_reports] = true if params[:with_security_reports].present?

        finder_params
      end

      override :send_git_archive
      def send_git_archive(repository, **kwargs)
        result = ::Users::Abuse::ProjectsDownloadBanCheckService.execute(current_user, repository.project)
        forbidden!(_('You are not allowed to download code from this project.')) if result.error?

        project = repository.project
        audit_event_type = project.public? ? 'public_repository_download_operation' : 'repository_download_operation'
        audit_context = {
          name: audit_event_type,
          ip_address: ip_address,
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new,
          target: project,
          scope: project,
          message: "Repository Download Started",
          target_details: project.full_path
        }
        ::Gitlab::Audit::Auditor.audit(audit_context)

        super
      end

      def private_token
        params[::APIGuard::PRIVATE_TOKEN_PARAM] || env[::APIGuard::PRIVATE_TOKEN_HEADER]
      end

      def warden
        env['warden']
      end

      # Check if the request is GET/HEAD, or if CSRF token is valid.
      def verified_request?
        ::Gitlab::RequestForgeryProtection.verified?(env)
      end

      # Check the Rails session for valid authentication details
      def find_user_from_warden
        warden.try(:authenticate) if verified_request?
      end

      def geo_token
        ::Gitlab::Geo.current_node.system_hook.token
      end

      def authorize_manage_saml!(group)
        unauthorized! unless can?(current_user, :admin_group_saml, group)
      end

      def check_group_saml_configured
        forbidden!('Group SAML not enabled.') unless ::Gitlab::Auth::GroupSaml::Config.enabled?
      end

      def check_instance_saml_configured
        forbidden!('SAML not enabled.') unless ::Gitlab::Auth::Saml::Config.enabled?
      end
    end
  end
end
