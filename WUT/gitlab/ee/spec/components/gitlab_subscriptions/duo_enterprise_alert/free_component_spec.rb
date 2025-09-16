# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterpriseAlert::FreeComponent, :saas, :aggregate_failures,
  type: :component, feature_category: :acquisition do
  let(:namespace) { build(:group, id: non_existing_record_id) }
  let(:user) { build(:user) }
  let(:title) { 'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise' }

  subject(:component) do
    render_inline(described_class.new(namespace: namespace, user: user)) && page
  end

  before do
    build(:gitlab_subscription, :free, namespace: namespace)
  end

  context 'when ultimate_trial plan' do
    before do
      build(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: namespace)
    end

    it { is_expected.not_to have_content(title) }
  end

  context 'when there is Duo Enterprise add-on' do
    before do
      allow(GitlabSubscriptions::DuoEnterprise)
        .to receive(:no_add_on_purchase_for_namespace?)
        .with(namespace)
        .and_return(false)
    end

    it { is_expected.not_to have_content(title) }
  end

  context 'when rendering' do
    it 'has the correct text' do
      is_expected.to have_content(title)

      is_expected.to have_content(
        'Start an Ultimate trial with GitLab Duo Enterprise to try the ' \
          'complete set of features from GitLab. GitLab Duo Enterprise gives ' \
          'you access to the full product offering from GitLab, including ' \
          'AI-native features. You can try it for free, no credit card required.'
      )
    end

    it 'has the primary action' do
      expected_link = new_trial_path(namespace_id: namespace.id)

      is_expected.to have_link(
        'Start free trial of GitLab Ultimate and GitLab Duo Enterprise',
        href: expected_link
      )

      expect(component.find(:link, href: expected_link))
        .to trigger_internal_events('click_duo_enterprise_trial_billing_page').on_click
        .with(additional_properties: { label: 'ultimate_and_duo_enterprise_trial' })
    end

    it 'has the hand raise lead selector' do
      is_expected.to have_selector('.js-hand-raise-lead-trigger')
    end
  end
end
