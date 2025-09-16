# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterpriseAlert::PremiumComponent, :saas, :aggregate_failures,
  type: :component, feature_category: :acquisition do
  let(:namespace) { build(:group, id: non_existing_record_id) }
  let(:user) { build(:user) }
  let(:eligible) { true }
  let(:title) { 'Get the most out of GitLab with Ultimate and GitLab Duo Enterprise' }

  let(:duo_pro_text) do
    'Not ready to trial the full suite of GitLab and GitLab Duo features? ' \
      'Start a free trial of GitLab Duo Pro instead.'
  end

  subject(:component) do
    render_inline(described_class.new(namespace: namespace, user: user)) && page
  end

  before do
    build(:gitlab_subscription, :premium, namespace: namespace)
    allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).with(namespace).and_return(eligible)
  end

  shared_examples 'has the Duo Enterprise text' do
    it 'has the text' do
      is_expected.to have_content(title)

      is_expected.to have_content(
        'Start an Ultimate trial with GitLab Duo Enterprise to try the ' \
          'complete set of features from GitLab. GitLab Duo Enterprise gives ' \
          'you access to the full product offering from GitLab, including ' \
          'AI-native features.'
      )
    end
  end

  shared_examples 'has the primary action' do
    it 'has the action' do
      expected_link = new_trial_path(namespace_id: namespace.id)

      is_expected.to have_link(
        'Start free trial of GitLab Ultimate and GitLab Duo Enterprise',
        href: expected_link
      )

      expect(component.find(:link, href: expected_link))
        .to trigger_internal_events('click_duo_enterprise_trial_billing_page').on_click
        .with(additional_properties: { label: 'ultimate_and_duo_enterprise_trial' })
    end
  end

  context 'when gold plan' do
    before do
      build(:gitlab_subscription, :gold, namespace: namespace)
    end

    it { is_expected.not_to have_content(title) }
  end

  context 'when is not eligible' do
    let(:eligible) { false }

    it { is_expected.not_to have_content(title) }
  end

  context 'with Duo Pro add-on' do
    before do
      allow(GitlabSubscriptions::DuoPro)
        .to receive(:any_add_on_purchase_for_namespace)
        .with(namespace)
        .and_return(build(:gitlab_subscription_add_on_purchase))
    end

    it_behaves_like 'has the Duo Enterprise text'
    it_behaves_like 'has the primary action'

    it { is_expected.not_to have_content(duo_pro_text) }
    it { is_expected.not_to have_content('Try GitLab Duo Pro') }
  end

  context 'when there are no add-ons' do
    it_behaves_like 'has the Duo Enterprise text'
    it_behaves_like 'has the primary action'

    it { is_expected.to have_content(duo_pro_text) }

    it 'has the secondary action' do
      expected_link = new_trials_duo_pro_path(namespace_id: namespace.id)

      is_expected.to have_link('Try GitLab Duo Pro', href: expected_link)

      expect(component.find(:link, href: expected_link))
        .to trigger_internal_events('click_duo_enterprise_trial_billing_page').on_click
        .with(additional_properties: { label: 'duo_pro_trial' })
    end
  end
end
