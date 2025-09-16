# frozen_string_literal: true

module Registrations
  class TrialWelcomeController < ApplicationController
    include ::Onboarding::SetRedirect

    before_action :verify_onboarding_enabled!
    before_action :enable_dark_mode

    feature_category :onboarding
    urgency :low

    layout 'minimal'

    def new
      render GitlabSubscriptions::Trials::Welcome::TrialFormComponent.new(user: current_user,
        params: params.permit(*::Onboarding::StatusPresenter::GLM_PARAMS))
    end

    private

    def enable_dark_mode
      @html_class = 'gl-dark'
    end
  end
end
