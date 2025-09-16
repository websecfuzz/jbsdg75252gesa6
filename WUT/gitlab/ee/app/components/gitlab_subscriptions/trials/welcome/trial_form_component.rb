# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module Welcome
      class TrialFormComponent < ViewComponent::Base
        def initialize(**kwargs)
          @user = kwargs[:user]
          @params = kwargs[:params]
        end

        private

        attr_reader :user, :params

        def form_data
          ::Gitlab::Json.generate(
            {
              userData: user_data,
              submitPath: submit_path,
              gtmSubmitEventLabel: 'saasTrialSubmit'
            }
          )
        end

        def user_data
          {
            firstName: user.first_name,
            lastName: user.last_name,
            emailDomain: user.email_domain,
            companyName: user.user_detail_organization,
            country: '',
            state: ''
          }
        end

        def submit_path
          # placeholder route
          trials_path(
            step: GitlabSubscriptions::Trials::UltimateCreateService::FULL,
            **params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS)
          )
        end
      end
    end
  end
end
