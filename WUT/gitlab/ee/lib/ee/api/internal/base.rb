# frozen_string_literal: true

module EE
  module API
    module Internal
      module Base
        extend ActiveSupport::Concern

        prepended do
          helpers do
            extend ::Gitlab::Utils::Override

            override :lfs_authentication_url
            def lfs_authentication_url(container)
              container.lfs_http_url_to_repo(params[:operation])
            end

            override :check_allowed
            def check_allowed(params)
              ip = params.fetch(:check_ip, nil)
              ::Gitlab::IpAddressState.with(ip) do # rubocop: disable CodeReuse/ActiveRecord
                super
              end
            end

            override :two_factor_manual_otp_check
            def two_factor_manual_otp_check
              return { success: false, message: 'Feature is not available' } unless ::License.feature_available?(:git_two_factor_enforcement)
              return { success: false, message: 'Feature flag is disabled' } unless ::Feature.enabled?(:two_factor_for_cli)

              actor.update_last_used_at!
              user = actor.user

              error_message = validate_actor(actor)

              return { success: false, message: error_message } if error_message

              return { success: false, message: 'Deploy keys cannot be used for Two Factor' } if actor.key.is_a?(DeployKey)

              return { success: false, message: 'Two-factor authentication is not enabled for this user' } unless user.two_factor_enabled?

              return { success: false, message: 'Your account is locked' } unless user.can?(:log_in)

              otp_validation_result = ::Users::ValidateManualOtpService.new(user).execute(params.fetch(:otp_attempt))

              if otp_validation_result[:status] == :success
                ::Gitlab::Auth::Otp::SessionEnforcer.new(actor.key).update_session
                { success: true }
              else
                user.increment_failed_attempts!
                ::Authn::UnauthenticatedSecurityEventAuditor.new(user, 'OTP').execute
                ::Gitlab::AppLogger.info(
                  message: 'Failed OTP login',
                  user_id: user.id,
                  failed_attempts: user.failed_attempts,
                  ip: request.ip
                )
                { success: false, message: 'Invalid OTP' }
              end
            end

            override :two_factor_push_otp_check
            def two_factor_push_otp_check
              return { success: false, message: 'Feature is not available' } unless ::License.feature_available?(:git_two_factor_enforcement)
              return { success: false, message: 'Feature flag is disabled' } unless ::Feature.enabled?(:two_factor_for_cli)

              actor.update_last_used_at!
              user = actor.user

              error_message = validate_actor(actor)

              return { success: false, message: error_message } if error_message

              return { success: false, message: 'Deploy keys cannot be used for Two Factor' } if actor.key.is_a?(DeployKey)

              return { success: false, message: 'Two-factor authentication is not enabled for this user' } unless user.two_factor_enabled?

              otp_validation_result = ::Users::ValidatePushOtpService.new(user).execute

              if otp_validation_result[:status] == :success
                ::Gitlab::Auth::Otp::SessionEnforcer.new(actor.key).update_session
                { success: true }
              else
                { success: false, message: 'Invalid OTP' }
              end
            end

            override :access_check_result
            def access_check_result
              super
            rescue Gitlab::GitAccess::GeoCustomSshError
              access_checker = access_checker_for(actor, params[:protocol])
              access_checker.geo_custom_ssh_action
            end
          end

          namespace 'internal' do
            get '/authorized_certs', feature_category: :source_code_management, urgency: :high do
              response = ::Groups::SshCertificates::FindService.new(params[:key], params[:user_identifier]).execute

              render_api_error!(response.message, response.reason) if response.error?

              group, user = response.payload.values_at(:group, :user)

              status 200

              {
                success: true,
                namespace: group.full_path,
                username: user.username
              }
            end
          end
        end
      end
    end
  end
end
