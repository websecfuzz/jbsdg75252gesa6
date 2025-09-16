# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::MembershipEnforcer, feature_category: :system_access do
  let(:user) { create(:user) }
  let(:identity) { create(:group_saml_identity, user: user) }
  let(:group) { identity.saml_provider.group }

  before do
    allow_any_instance_of(SamlProvider).to receive(:enforced_sso?).and_return(true)
  end

  it 'allows adding a user linked to the SAML account as member' do
    expect(described_class.new(group).can_add_user?(user)).to be_truthy
  end

  it 'does not allow adding a user not linked to the SAML account as member' do
    non_saml_user = create(:user)

    expect(described_class.new(group).can_add_user?(non_saml_user)).to be_falsey
  end

  context 'when the user has an inactive scim identity' do
    before do
      stub_licensed_features(extended_audit_events: true)
      create(:group_scim_identity, group: group, user: user, active: false)
    end

    it 'does not allow adding a user with an inactive scim identity for the group' do
      expect(described_class.new(group).can_add_user?(user)).to be_falsey
    end

    it 'logs an audit event' do
      expect { described_class.new(group).can_add_user?(user) }.to change { AuditEvent.count }.by(1)

      expect(AuditEvent.last).to have_attributes({
        attributes: hash_including({
          "entity_id" => group.id,
          "entity_type" => "Group",
          "author_id" => user.id,
          "target_details" => user.username,
          "target_id" => user.id
        }),
        details: hash_including({
          custom_message: "User cannot be added to group due to inactive SCIM identity",
          target_type: "User",
          target_details: user.username
        })
      })
    end
  end

  it 'does allow adding a user with an active scim identity for the group' do
    _inactive_scim_identity_for_other_user = create(:group_scim_identity, group: group, user: create(:user),
      active: false)
    create(:group_scim_identity, group: group, user: user, active: true)

    expect(described_class.new(group).can_add_user?(user)).to be_truthy
  end

  it 'allows adding a project bot as member' do
    project_bot = create(:user, :project_bot)

    expect(described_class.new(group).can_add_user?(project_bot)).to be_truthy
  end

  context 'when the user is a service account' do
    let_it_be(:service_account) { create(:service_account) }

    it 'allows adding a service account provisioned by the root group' do
      service_account.update!(provisioned_by_group: group)

      expect(described_class.new(group).can_add_user?(service_account)).to be_truthy
    end

    it 'does not allow adding a service account provisioned by another root group' do
      service_account.update!(provisioned_by_group: create(:group))

      expect(described_class.new(group).can_add_user?(service_account)).to be_falsey
    end
  end
end
