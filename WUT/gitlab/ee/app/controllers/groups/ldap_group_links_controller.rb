# frozen_string_literal: true

class Groups::LdapGroupLinksController < Groups::ApplicationController
  before_action :group
  before_action :require_ldap_enabled
  before_action :authorize_admin_group!
  before_action :authorize_manage_ldap_group_links!

  layout 'group_settings'

  feature_category :system_access

  def index; end

  def create
    ldap_group_link = @group.ldap_group_links.build(ldap_group_link_params)
    if ldap_group_link.save
      if request.referer && request.referer.include?('admin')
        redirect_to [:admin, @group], notice: 'New LDAP link saved'
      else
        redirect_back_or_default(default: { action: 'index' }, options: { notice: 'New LDAP link saved' })
      end
    else
      redirect_back_or_default(
        default: { action: 'index' },
        options: { alert: "Could not create new LDAP link: #{ldap_group_link.errors.full_messages * ', '}" }
      )
    end
  end

  def destroy
    @group.ldap_group_links.id_in(params[:id]).destroy_all # rubocop: disable Cop/DestroyAll
    redirect_back_or_default(default: { action: 'index' }, options: { notice: 'LDAP link removed' })
  end

  private

  def authorize_manage_ldap_group_links!
    render_404 unless can?(current_user, :admin_ldap_group_links, group)
  end

  def require_ldap_enabled
    render_404 unless Gitlab.config.ldap.enabled
  end

  def ldap_group_link_params
    attrs = %i[cn group_access provider]
    attrs << :filter if ::License.feature_available?(:ldap_group_sync_filter)
    attrs << :member_role_id if group.custom_roles_enabled?

    params.require(:ldap_group_link).permit(attrs)
  end
end
