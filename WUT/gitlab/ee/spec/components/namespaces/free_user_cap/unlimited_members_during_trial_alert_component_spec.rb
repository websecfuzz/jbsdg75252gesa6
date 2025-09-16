# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap::UnlimitedMembersDuringTrialAlertComponent, :saas, type: :component, feature_category: :seat_cost_management do
  let(:user) { build(:user) }
  let(:namespace) { build(:group, :private, id: non_existing_record_id) }
  let(:wrapper_class) { 'test-content' }
  let(:trial_ends_on) { Date.current + 15.days }
  let(:owner_access?) { true }
  let(:dashboard_limit_enabled?) { true }
  let(:trial?) { true }
  let(:params) { { namespace: namespace, user: user, wrapper_class: wrapper_class } }

  subject(:component) { described_class.new(**params) }

  before do
    stub_feature_flags(streamlined_first_product_experience: false)
    ::Onboarding::Progress.onboard(namespace)
    build(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: namespace, trial: trial?)
    stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled?)
    stub_ee_application_setting(dashboard_limit: 0)
    allow(Ability).to receive(:allowed?).with(user, :owner_access, namespace).and_return(owner_access?)
  end

  describe '#render' do
    context 'when the alert should be shown' do
      it 'renders the alert component with correct content' do
        render_inline(component)

        expect(page).to have_css('.js-unlimited-members-during-trial-alert')
        expect(page).to have_content('Get the most out of your trial with space for more members')
        expect(page).to have_content("During your trial, invite as many members as you like to " \
          "#{namespace.name} to collaborate with you."
                                    )
        expect(page).to have_content("When your trial ends, you'll have a maximum of 0 members on the Free tier")
        expect(page).to have_css("[data-feature-id='unlimited_members_during_trial_alert']")
        expect(page).to have_css("[data-group-id='#{namespace.id}']")
        expect(page).to have_css("[data-testid='unlimited-members-during-trial-alert']")
      end
    end

    context 'when the alert should not be shown' do
      shared_examples_for 'not rendering the alert' do
        it 'does not render the alert' do
          render_inline(component)
          expect(page).not_to have_css("[data-testid='unlimited-members-during-trial-alert']")
          expect(page).not_to have_css('.js-unlimited-members-during-trial-alert')
        end
      end

      context 'when feature flag `streamlined_first_product_experience` is enabled' do
        before do
          stub_feature_flags(streamlined_first_product_experience: true)
        end

        it_behaves_like 'not rendering the alert'
      end

      context 'when the namespace is not qualified' do
        let(:dashboard_limit_enabled?) { false }

        it_behaves_like 'not rendering the alert'
      end

      context 'when user is not an owner of the namespace' do
        let(:owner_access?) { false }

        it_behaves_like 'not rendering the alert'
      end

      context 'when the namespace is not on an active trial' do
        let(:trial?) { false }

        it_behaves_like 'not rendering the alert'
      end

      context 'when it is dismissed' do
        let(:user) do
          build(:user, group_callouts: [
            build(:group_callout, group: namespace, feature_name: 'unlimited_members_during_trial_alert')
          ])
        end

        it_behaves_like 'not rendering the alert'
      end

      context 'when user completed inviting members' do
        before do
          ::Onboarding::Progress.register(namespace, :user_added)
        end

        it_behaves_like 'not rendering the alert'
      end
    end

    context 'when hiding the invite members button' do
      let(:params) { super().merge(hide_invite_members_button: true) }

      it 'only renders the "Explore paid plans" button' do
        render_inline(component)

        expect(page).to have_link('Explore paid plans', href: group_billings_path(namespace), class: 'btn-confirm')
        expect(page).not_to have_css('.js-invite-members-trigger')
      end
    end

    context 'when not hiding the invite members button' do
      it 'renders the "Invite more members" trigger and "Explore paid plans" button' do
        render_inline(component)

        expect(page).to have_css('.js-invite-members-trigger')
        expect(page).to have_link('Explore paid plans', href: group_billings_path(namespace), class: 'btn-default')
      end
    end

    context 'when on billing page' do
      let(:params) { super().merge(hide_explore_paid_plans_button: true) }

      it 'does not render the secondary CTA' do
        render_inline(component)

        expect(page).not_to have_link('Explore paid plans', href: group_billings_path(namespace), class: 'btn-default')
      end
    end
  end
end
