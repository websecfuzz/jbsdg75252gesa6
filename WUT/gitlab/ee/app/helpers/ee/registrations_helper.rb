# frozen_string_literal: true

module EE
  module RegistrationsHelper
    include ::Gitlab::Utils::StrongMemoize
    extend ::Gitlab::Utils::Override

    def shuffled_registration_objective_options
      options = registration_objective_options
      other = options.extract!(:other).to_a.flatten
      status_values = ::UserDetail.onboarding_status_registration_objectives

      options.to_a.shuffle.append(other).map do |key, label|
        [label, status_values[key]]
      end
    end

    def arkose_labs_data
      path = data_exchange_payload_path

      data = {
        api_key: ::AntiAbuse::IdentityVerification::Settings.arkose_public_api_key,
        domain: ::AntiAbuse::IdentityVerification::Settings.arkose_labs_domain,
        data_exchange_payload: arkose_data_exchange_payload(Arkose::DataExchangePayload::USE_CASE_SIGN_UP),
        data_exchange_payload_path: path
      }

      data.compact
    end

    def unconfirmed_email_feature_enabled?
      ::Gitlab::CurrentSettings.delete_unconfirmed_users? &&
        (::Gitlab::CurrentSettings.email_confirmation_setting_soft? ||
         ::Gitlab::CurrentSettings.email_confirmation_setting_hard?) &&
        ::License.feature_available?(:delete_unconfirmed_users)
    end

    def unconfirmed_email_text
      format(
        _("You must confirm your email within %{cut_off_days} days of signing up. " \
          "If you do not confirm your email in this timeframe, your account will be deleted and " \
          "you will need to sign up for GitLab again."),
        cut_off_days: ::Gitlab::CurrentSettings.unconfirmed_users_delete_after_days
      )
    end

    private

    def registration_objective_options
      localized_jobs_to_be_done_choices.dup
    end
  end
end
