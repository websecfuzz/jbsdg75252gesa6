# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRole, feature_category: :permissions do
  subject(:admin_role) { build(:admin_role) }

  it "includes the AdminRollable Concern" do
    expect(described_class.included_modules).to include(Authz::AdminRollable)
  end

  describe 'associations' do
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:user_admin_roles) }
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }

    context 'for json schema' do
      Gitlab::CustomRoles::Definition.admin.each_key do |permission|
        context "for #{permission}" do
          it_behaves_like 'validates jsonb boolean field', permission, :permissions
        end
      end

      context 'when trying to store a member_role permission key' do
        Gitlab::CustomRoles::Definition.standard.each_key do |permission|
          context "for #{permission}" do
            it { is_expected.not_to allow_value({ permission => true }).for(:permissions) }
          end
        end
      end
    end

    context 'for ensure_at_least_one_permission_is_enabled' do
      context 'with at least one permission enabled' do
        it { is_expected.to be_valid }
      end

      context 'with no permissions enabled' do
        subject(:admin_role) { build(:admin_role, without_any_permissions: true) }

        it 'is invalid' do
          expect(admin_role).not_to be_valid
          expect(admin_role.errors[:base].first)
            .to include(s_('MemberRole|Cannot create a member role with no enabled permissions'))
        end
      end
    end
  end

  describe 'callbacks' do
    let_it_be_with_reload(:admin_role) { create(:admin_role) }

    it 'allows deletion without any user associated' do
      expect(admin_role.destroy).to be_truthy
    end

    it 'prevent deletion when user is associated' do
      create(:user_admin_role, admin_role: admin_role)

      admin_role.user_admin_roles.reload

      expect(admin_role.destroy).to be_falsey
      expect(admin_role.errors.messages[:base]).to(include(
        s_('MemberRole|Admin role is assigned to one or more users. Remove role from all users, then delete role.')
      ))
    end
  end

  describe '.all_customizable_permissions' do
    subject(:all_customizable_permissions) { described_class.all_customizable_permissions }

    it { is_expected.to eq(Gitlab::CustomRoles::Definition.admin) }
  end

  describe '#enabled_admin_permissions' do
    let(:admin_role) { build(:admin_role, *permissions.keys) }

    subject { admin_role.enabled_admin_permissions }

    context 'when some permissions are enabled' do
      let(:permissions) { Gitlab::CustomRoles::Definition.admin.to_a.sample(3).to_h }

      it { is_expected.to match_array(permissions) }
    end
  end

  describe 'admin_related_role?' do
    subject(:admin_related_role) { admin_role.admin_related_role? }

    it { is_expected.to be true }
  end
end
