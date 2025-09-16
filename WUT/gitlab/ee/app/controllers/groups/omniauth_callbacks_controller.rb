# frozen_string_literal: true

class Groups::OmniauthCallbacksController < OmniauthCallbacksController
  extend ::Gitlab::Utils::Override
  include InternalRedirect

  skip_before_action :verify_authenticity_token, only: [:failure, :group_saml]

  before_action :log_saml_response, only: [:group_saml]

  feature_category :system_access
  urgency :low

  def group_saml
    @unauthenticated_group = Group.find_by_full_path(params[:group_id])
    @saml_provider = @unauthenticated_group.saml_provider

    identity_linker = Gitlab::Auth::GroupSaml::IdentityLinker.new(current_user, oauth, session, @saml_provider)

    store_location_for(:redirect, saml_redirect_path)
    omniauth_flow(Gitlab::Auth::GroupSaml, identity_linker: identity_linker)
  rescue Gitlab::Auth::Saml::IdentityLinker::UnverifiedRequest
    redirect_unverified_saml_initiation
  end

  private

  override :link_identity
  def link_identity(identity_linker)
    super.tap do
      store_active_saml_session unless identity_linker.failed?
    end
  end

  override :redirect_identity_linked
  def redirect_identity_linked
    flash[:notice] = s_("SAML|Your organization's SSO has been connected to your GitLab account")

    redirect_to after_sign_in_path_for(current_user)
  end

  override :redirect_identity_link_failed
  def redirect_identity_link_failed(error_message)
    flash[:alert] = format(
      s_("GroupSAML|%{group_name} SAML authentication failed: %{message}"),
      group_name: @unauthenticated_group.name,
      message: error_message
    )

    redirect_to root_path
  end

  override :sign_in_and_redirect
  def sign_in_and_redirect(user, *args)
    super.tap { flash[:notice] = "Signed in with SAML for #{@unauthenticated_group.name}" }
  end

  override :sign_in
  def sign_in(resource_or_scope, *args)
    store_active_saml_session

    super
  end

  override :prompt_for_two_factor
  def prompt_for_two_factor(user)
    store_active_saml_session

    super
  end

  override :locked_user_redirect
  def locked_user_redirect(user)
    redirect_to_group_sso(alert: locked_user_redirect_alert(user))
  end

  def redirect_to_group_sso(alert: nil)
    flash[:alert] = alert if alert

    redirect_to sso_group_saml_providers_path(@unauthenticated_group, token: @unauthenticated_group.saml_discovery_token)
  end

  def store_active_saml_session
    Gitlab::Auth::GroupSaml::SsoEnforcer.new(@saml_provider).update_session(
      session_not_on_or_after: session_not_on_or_after_attribute)
  end

  def redirect_unverified_saml_initiation
    flash[:notice] = "Request to link SAML account must be authorized"

    redirect_to sso_group_saml_providers_path(@unauthenticated_group)
  end

  override :after_sign_in_path_for
  def after_sign_in_path_for(resource)
    path = saml_redirect_path

    # Ensure that if redirecting to the SAML group path, check the user has access first.
    if path == group_path(@unauthenticated_group)
      path = safe_group_path(@unauthenticated_group) || dashboard_groups_path
    end

    path || super
  end

  override :build_auth_user
  def build_auth_user(auth_user_class)
    super.tap do |auth_user|
      auth_user.saml_provider = @saml_provider
    end
  end

  override :fail_login
  def fail_login(user)
    return redirect_to_login_or_register if email_already_taken?(user)

    error_message = email_blank?(user) ? email_blank_error_message : user.errors.full_messages.to_sentence
    redirect_to_group_sso(alert: error_message)
  end

  def redirect_to_login_or_register
    notice = s_("SAML|There is already a GitLab account associated with this email address. Sign in with your existing credentials to connect your organization's account")

    after_gitlab_sign_in = sso_group_saml_providers_path(@unauthenticated_group)

    store_location_for(:redirect, after_gitlab_sign_in)

    redirect_to new_user_session_path, notice: notice
  end

  def saml_redirect_path
    safe_relay_state || group_path(@unauthenticated_group)
  end

  def safe_group_path(group)
    return unless can?(current_user, :read_group, group)

    group_path(group)
  end

  def safe_relay_state
    valid_gitlab_initiated_saml_request? && safe_redirect_path(params['RelayState'])
  end

  override :find_message
  def find_message(kind, options = {})
    _('Unable to sign in to group with SAML: "%{reason}"') % options
  end

  override :after_omniauth_failure_path_for
  def after_omniauth_failure_path_for(scope)
    group_saml_failure_path(scope)
  end

  def group_saml_failure_path(scope)
    group = Gitlab::Auth::GroupSaml::GroupLookup.new(request.env).group

    unless can?(current_user, :sign_in_with_saml_provider, group&.saml_provider)
      OmniAuth::Strategies::GroupSaml.invalid_group!(group&.path)
    end

    if can?(current_user, :admin_group_saml, group)
      group_saml_providers_path(group)
    else
      sso_group_saml_providers_path(group)
    end
  end

  def email_already_taken?(user)
    email_error?(user, _('has already been taken'))
  end

  def email_blank?(user)
    email_error?(user, _("can't be blank"))
  end

  def email_error?(user, error_text)
    user && user.errors['email'].any?(error_text)
  end

  def email_blank_error_message
    s_('SAML|The SAML response did not contain an email address. Either the SAML identity provider is not configured to send the attribute, or the identity provider directory does not have an email address value for your user.')
  end

  override :log_audit_event
  def log_audit_event(user, options = {})
    return if options[:with].blank?

    provider = options[:with]
    audit_context = {
      name: 'authenticated_with_group_saml',
      author: user,
      scope: @unauthenticated_group,
      target: user,
      message: "Signed in with #{provider.upcase} authentication",
      authentication_event: true,
      authentication_provider: provider,
      additional_details: {
        with: provider,
        registration_details: user.registration_audit_details
      }
    }

    ::Gitlab::Audit::Auditor.audit(audit_context)
  end

  def log_saml_response
    ParameterFilters::SamlResponse.log(params['SAMLResponse'].dup)
  end
end
