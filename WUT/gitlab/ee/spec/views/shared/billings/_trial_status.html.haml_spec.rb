# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/billings/_trial_status.html.haml', :saas do
  include ApplicationHelper

  let_it_be(:group) { create(:group) }

  let(:plan) { nil }
  let(:trial_ends_on) { nil }
  let(:trial) { false }

  before do
    allow(group).to receive(:eligible_for_trial?).and_return(false)

    create(:gitlab_subscription, namespace: group, hosted_plan: plan, trial_starts_on: Time.current, trial_ends_on: trial_ends_on, trial: trial)
  end

  context 'when not eligible for trial' do
    it 'offers to learn more about plans' do
      render 'shared/billings/trial_status', namespace: group
      expect(rendered).to have_content("Learn more about each plan by visiting our")
    end
  end

  context 'when trial active' do
    let(:trial_ends_on) { Date.tomorrow }
    let(:trial) { true }

    context 'with a ultimate trial' do
      let(:plan) { create(:ultimate_plan) }

      it 'displays expiry date and Ultimate' do
        render 'shared/billings/trial_status', namespace: group

        expect(rendered).to have_content("Your GitLab.com Ultimate trial will expire after #{trial_ends_on}. You can retain access to the Ultimate features by upgrading below.")
      end
    end

    context 'with a premium trial' do
      let(:plan) { create(:premium_plan) }

      it 'displays expiry date and Premium' do
        render 'shared/billings/trial_status', namespace: group

        expect(rendered).to have_content("Your GitLab.com Premium trial will expire after #{trial_ends_on}. You can retain access to the Premium features by upgrading below.")
      end
    end

    context 'with an ultimate trial using the new trial plan' do
      let(:plan) { create(:ultimate_trial_plan) }

      it 'displays expiry date and Ultimate' do
        render 'shared/billings/trial_status', namespace: group

        expect(rendered).to have_content("Your GitLab.com Ultimate trial will expire after #{trial_ends_on}. You can retain access to the Ultimate features by upgrading below.")
      end
    end

    context 'with a premium trial using the new trial plan' do
      let(:plan) { create(:premium_trial_plan) }

      it 'displays expiry date and Premium' do
        render 'shared/billings/trial_status', namespace: group

        expect(rendered).to have_content("Your GitLab.com Premium trial will expire after #{trial_ends_on}. You can retain access to the Premium features by upgrading below.")
      end
    end
  end
end
