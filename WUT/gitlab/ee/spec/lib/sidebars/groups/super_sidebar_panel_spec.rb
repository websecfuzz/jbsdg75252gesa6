# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarPanel, feature_category: :navigation do
  let(:user) { build_stubbed(:user) }
  let(:group) { create(:group, owners: user) }

  let(:context) do
    Sidebars::Groups::Context.new(
      current_user: user,
      container: group,
      is_super_sidebar: true,
      # Turn features off that do not add/remove menu items
      show_promotions: false,
      show_discover_group_security: false
    )
  end

  subject { described_class.new(context) }

  # We want to enable _all_ possible menu items for these specs
  before do
    # Give the user access to everything and enable every feature
    allow(Ability).to receive(:allowed?).and_return(true)
    allow(group).to receive(:licensed_feature_available?).and_return(true)
    # Needed to show Container Registry items
    allow(::Gitlab.config.registry).to receive(:enabled).and_return(true)
    # Needed to show Billing
    allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(true)
    # Needed to show LDAP Group Sync
    allow(::Gitlab::Auth::Ldap::Config).to receive(:group_sync_enabled?).and_return(true)
    # Needed for Domain Verification entry
    allow(group).to receive(:domain_verification_available?).and_return(true)
    # Needed for GitLab Duo menu item
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    # Needed for Roles and permissions
    stub_saas_features(gitlab_com_subscriptions: true)
    # Needed for virtual registry
    stub_config(dependency_proxy: { enabled: true })
  end

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel with all menu_items categorized'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'
end
