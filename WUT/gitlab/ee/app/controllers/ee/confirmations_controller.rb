# frozen_string_literal: true

module EE
  module ConfirmationsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::AuditEvents::Changes

    prepended do
      include GoogleAnalyticsCSP
      include GoogleSyndicationCSP
    end

    protected

    override :after_sign_in
    def after_sign_in(resource)
      audit_changes(:email, as: 'email address', model: resource, event_type: 'user_email_changed_and_user_signed_in')

      super(resource)
    end

    override :sign_in_path
    def sign_in_path(user)
      group = user.provisioned_by_group

      if group
        sso_group_saml_providers_path(group, token: group.saml_discovery_token)
      else
        super(user)
      end
    end
  end
end
