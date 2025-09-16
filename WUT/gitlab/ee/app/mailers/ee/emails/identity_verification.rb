# frozen_string_literal: true

module EE
  module Emails
    module IdentityVerification
      include ::Gitlab::Email::SingleRecipientValidator

      def confirmation_instructions_email(email, token:)
        validate_single_recipient_in_email!(email)

        @token = token
        @expires_in_minutes = ::Users::EmailVerification::ValidateTokenService::TOKEN_VALID_FOR_MINUTES

        headers = {
          to: email,
          subject: s_('IdentityVerification|Confirm your email address'),
          'X-Mailgun-Suppressions-Bypass' => 'true'
        }

        mail_with_locale(headers) do |format|
          format.html { render layout: 'mailer' }
          format.text
        end
      end
    end
  end
end
