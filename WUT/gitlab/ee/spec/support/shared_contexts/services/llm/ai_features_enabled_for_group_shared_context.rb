# frozen_string_literal: true

RSpec.shared_context 'with ai features enabled for group' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    stub_licensed_features(
      ai_features: true,
      glab_ask_git_command: true,
      generate_description: true
    )
    group.namespace_settings.reload.update!(experiment_features_enabled: true)
  end
end

RSpec.shared_context 'with experiment features disabled for group' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings)
      .to receive_messages(experiment_settings_allowed?: true, prompt_cache_settings_allowed?: true)
    stub_licensed_features(
      glab_ask_git_command: true,
      ai_features: true,
      generate_description: true
    )
    group.namespace_settings.update!(experiment_features_enabled: false)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for self-managed' do
  include_context 'with duo pro self-managed addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for self-managed' do
  include_context 'with duo pro self-managed addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: false)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for self-managed' do
  include_context 'with duo pro self-managed addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: false)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features always off for self-managed' do
  include_context 'with duo pro self-managed addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: false)
    stub_licensed_features(ai_chat: true)
    stub_application_setting(lock_duo_features_enabled: true)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for group on SaaS' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features enabled and agentic chat available for group on SaaS' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(agentic_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true, experiment_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for group on SaaS' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: false)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for group on SaaS' do
  include_context 'with duo pro addon'

  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: false)
  end
end

RSpec.shared_context 'with duo pro addon' do
  # To accommodate existing specs that use this config
  # this helper assign seat in an addon for both
  # current_user or user depends on which one is defined
  before do
    the_user = if defined?(current_user) && current_user.present?
                 current_user
               elsif defined?(user) && user.present?
                 user
               else
                 false
               end

    if the_user
      # As this context could be included in tests multiple times,
      # we first search by active purchases and are trying to not create
      # entities twice because it will cause an ActiveRecord error in tests
      active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)
      add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions, group)

      active_purchase ||= create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: group)

      active_assignment = GitlabSubscriptions::UserAddOnAssignment.find_by(
        user: the_user, add_on_purchase: active_purchase)

      unless active_assignment
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: the_user,
          add_on_purchase: active_purchase
        )
      end
    end
  end
end

RSpec.shared_context 'with duo pro self-managed addon' do
  # To accommodate existing specs that use this config
  # this helper assign seat in an addon for both
  # current_user or user depends on which one is defined
  before do
    the_user = if defined?(current_user) && current_user.present?
                 current_user
               elsif defined?(user) && user.present?
                 user
               else
                 false
               end

    if the_user
      # As this context could be included in tests multiple times,
      # we first search by active purchases and are trying to not create
      # entities twice because it will cause an ActiveRecord error in tests
      active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: nil)
      add_on = GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions)

      active_purchase ||= create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: nil)

      active_assignment = GitlabSubscriptions::UserAddOnAssignment.find_by(
        user: the_user, add_on_purchase: active_purchase)

      unless active_assignment
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: the_user,
          add_on_purchase: active_purchase
        )
      end
    end
  end
end

# This context is the same as the one for Duo Pro
# only difference is the purchased addon
RSpec.shared_context 'with duo enterprise addon' do
  before do
    the_user = if defined?(current_user) && current_user.present?
                 current_user
               elsif defined?(user) && user.present?
                 user
               else
                 false
               end

    if the_user
      active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)

      active_purchase ||= create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)

      active_assignment = GitlabSubscriptions::UserAddOnAssignment.find_by(
        user: the_user, add_on_purchase: active_purchase)

      unless active_assignment
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: the_user,
          add_on_purchase: active_purchase
        )
      end
    end
  end
end

# This context is the same as the ones for Duo Pro and Enterprise
# only difference is the purchased addon
RSpec.shared_context 'with duo core addon' do
  before do
    the_user = if defined?(current_user) && current_user.present?
                 current_user
               elsif defined?(user) && user.present?
                 user
               else
                 false
               end

    if the_user
      active_purchase = GitlabSubscriptions::AddOnPurchase.find_by(namespace: group)

      active_purchase || create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group)
    end
  end
end
