# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::NamespaceLimit::UserPreEnforcementAlertComponent, :saas, type: :component,
  feature_category: :consumables_cost_management do
  include ActionView::Helpers::NumberHelper
  include NamespaceStorageHelpers
  include StorageHelper

  let_it_be_with_refind(:user) { create(:user, :with_namespace) }

  subject(:component) { described_class.new(context: user.namespace, user: user) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true, automatic_purchased_storage_allocation: true)
  end

  context 'when user namespace' do
    before do
      allow(user.namespace).to receive(:user_namespace?).and_return(true)

      create(
        :namespace_root_storage_statistics,
        namespace: user.namespace,
        storage_size: 5.gigabytes
      )
    end

    context 'when a notification limit has not been set' do
      it 'does not include used storage in the alert text' do
        render_inline(component)

        expect(page).not_to have_text storage_counter(5.gigabytes)
      end
    end

    context 'when a notification limit has been set' do
      before do
        create(:plan_limits, plan: user.namespace.root_ancestor.actual_plan, notification_limit: 500)
        set_dashboard_limit(user.namespace, megabytes: 5_120, enabled: false)
      end

      it 'includes used storage in the alert text' do
        render_inline(component)

        expect(page).to have_text storage_counter(5.gigabytes)
      end

      it 'includes the correct navigation instruction in the alert text' do
        render_inline(component)

        expect(page).to have_text 'View and manage your usage from User settings > Usage quotas'
      end

      context 'when the user dismissed the alert under 14 days ago', :freeze_time do
        before do
          create(
            :callout,
            user: user,
            feature_name: 'namespace_storage_pre_enforcement_banner',
            dismissed_at: 1.day.ago
          )
        end

        it 'does not render the alert' do
          render_inline(component)

          expect(page).not_to have_text "A namespace storage limit of 5 GiB will soon be enforced"
        end
      end

      context 'when the user dismissed the alert over 14 days ago', :freeze_time do
        before do
          create(
            :callout,
            user: user,
            feature_name: 'namespace_storage_pre_enforcement_banner',
            dismissed_at: 14.days.ago
          )
        end

        it 'does render the alert' do
          render_inline(component)

          expect(page).to have_text "A namespace storage limit of 5 GiB will soon be enforced"
        end
      end
    end
  end
end
