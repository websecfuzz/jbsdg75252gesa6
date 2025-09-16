# frozen_string_literal: true

class LightweightTrialRegistrationRedesignExperiment < ApplicationExperiment
  control
  variant(:candidate)

  exclude :non_new_trial_registrations

  private

  def control_behavior; end
  def candidate_behavior; end

  def non_new_trial_registrations
    actor = context.try(:actor)
    return false unless actor
    return false if actor.is_a? String # not logged in yet

    actor.onboarding_status_version.blank? || actor.onboarding_status_initial_registration_type != 'trial'
  end
end
