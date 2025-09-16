# frozen_string_literal: true

class Groups::SsoController < Groups::ApplicationController
  include InternalRedirect
  include OneTrustCSP

  skip_before_action :group

  before_action :init_preferred_language
  before_action :authenticate_user!, only: [:unlink]
  before_action :require_group_saml_instance!
  before_action :require_licensed_group!, except: [:unlink]
  before_action :require_saml_provider!
  before_action :require_enabled_provider!, except: [:unlink]
  before_action :check_user_can_sign_in_with_provider, only: [:saml]
  before_action :group, only: [:saml]
  before_action :redirect_if_group_moved

  layout 'devise'

  feature_category :system_access
  urgency :low

  def saml
    session_redirect = if ::Feature.enabled?(:ff_oauth_redirect_to_sso_login, group.root_ancestor)
                         session[:user_return_to]
                       end

    @redirect_path = session_redirect || safe_redirect_path(params[:redirect]) || group_path(unauthenticated_group)
    @group_path = unauthenticated_group.path
    @group_name = unauthenticated_group.full_name
    @group_saml_identity = linked_identity
    @auto_redirect_to_provider = current_user&.group_sso?(unauthenticated_group)

    render layout: 'devise_empty' if @auto_redirect_to_provider
  end

  def unlink
    return route_not_found unless linked_identity

    GroupSaml::Identity::DestroyService.new(linked_identity).execute

    redirect_to profile_account_path
  end

  private

  def group
    @group ||= unauthenticated_group
  end

  def linked_identity
    @linked_identity ||= GroupSamlIdentityFinder.new(user: current_user).find_linked(group: unauthenticated_group)
  end

  def unauthenticated_group
    @unauthenticated_group ||= Group.find_by_full_path(params[:group_id], follow_redirects: true)
  end

  def require_group_saml_instance!
    route_not_found unless Gitlab::Auth::GroupSaml::Config.enabled?
  end

  def require_licensed_group!
    route_not_found unless unauthenticated_group&.feature_available?(:group_saml)
  end

  def require_saml_provider!
    redirect_settings_or_not_found unless unauthenticated_group.saml_provider
  end

  def require_enabled_provider!
    redirect_settings_or_not_found unless unauthenticated_group.saml_provider&.enabled?
  end

  def redirect_settings_or_not_found
    if can?(current_user, :admin_group_saml, unauthenticated_group)
      flash[:notice] = 'SAML sign on has not been configured for this group'
      redirect_to [@unauthenticated_group, :saml_providers]
    else
      route_not_found
    end
  end

  def check_user_can_sign_in_with_provider
    actor = saml_discovery_token_actor || current_user
    route_not_found unless can?(actor, :sign_in_with_saml_provider, unauthenticated_group.saml_provider)
  end

  def saml_discovery_token_actor
    Gitlab::Auth::GroupSaml::TokenActor.new(params[:token]) if params[:token]
  end

  def redirect_if_group_moved
    ensure_canonical_path(unauthenticated_group, params[:group_id])
  end
end
