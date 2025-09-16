# frozen_string_literal: true

module EE
  module SessionsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      include GoogleAnalyticsCSP
      include GoogleSyndicationCSP

      before_action :gitlab_geo_logout, only: [:destroy]
      prepend_before_action :detect_and_notify_for_compromised_password, only: [:create]
      prepend_before_action :complete_identity_verification, only: :create
    end

    override :new
    def new
      return super if signed_in?

      if ::Gitlab::Geo.secondary_with_primary?
        current_node_uri = URI(GeoNode.current_node_url)
        state = geo_login_state.encode
        redirect_to oauth_geo_auth_url(host: current_node_uri.host, port: current_node_uri.port, state: state)
      else
        super
      end
    end

    private

    def gitlab_geo_logout
      return unless ::Gitlab::Geo.secondary?

      # The @geo_logout_state instance variable is used within
      # ApplicationController#after_sign_out_path_for to redirect
      # the user to the logout URL on the primary after sign out
      # on the secondary.
      @geo_logout_state = geo_logout_state.encode # rubocop:disable Gitlab/ModuleWithInstanceVariables
    end

    def geo_login_state
      ::Gitlab::Geo::Oauth::LoginState.new(return_to: sanitize_redirect(geo_return_to_after_login))
    end

    def geo_logout_state
      ::Gitlab::Geo::Oauth::LogoutState.new(token: session[:access_token], return_to: geo_return_to_after_logout)
    end

    def geo_return_to_after_login
      stored_redirect_uri || ::Gitlab::Utils.append_path(root_url, session[:user_return_to].to_s)
    end

    def geo_return_to_after_logout
      safe_redirect_path_for_url(request.referer)
    end

    override :log_failed_login
    def log_failed_login
      login = request.filtered_parameters.dig('user', 'login')
      otp_user_id = session[:otp_user_id]

      user = if otp_user_id
               ::User.find_by_id(otp_user_id)
             elsif login
               ::User.find_by_login(login)
             end

      ::Authn::UnauthenticatedSecurityEventAuditor.new(login.presence || user || 'unknown').execute

      super
    end

    def complete_identity_verification
      user = find_user

      return if !user || !user.valid_password?(user_params[:password]) || user.access_locked?
      return if ::Gitlab::Qa.request?(request.user_agent)
      return if !user.signup_identity_verification_enabled? || user.signup_identity_verified?

      # When identity verification is enabled, store the user id in the session and redirect to the
      # identity verification page instead of displaying a Devise flash alert on the sign in page.
      session[:verification_user_id] = user.id
      redirect_to signup_identity_verification_path
    end

    def detect_and_notify_for_compromised_password
      user = find_user

      ::Gitlab::AppJsonLogger.info(
        message: 'Checking for compromised password',
        exposed_credential_check_header: request.headers['HTTP_EXPOSED_CREDENTIAL_CHECK'],
        user_id: user&.id)

      return unless user.present?

      ::Users::CompromisedPasswords::DetectAndNotifyService.new(user, user_params[:password], request).execute
    end

    override :onboarding_status_tracking_label
    def onboarding_status_tracking_label
      onboarding_status_presenter.preregistration_tracking_label
    end

    def onboarding_status_presenter
      ::Onboarding::StatusPresenter
        .new(params.permit(:invite_email).to_h.deep_symbolize_keys, session['user_return_to'], resource)
    end
    strong_memoize_attr :onboarding_status_presenter
  end
end
