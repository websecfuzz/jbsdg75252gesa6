# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRollable, feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  subject(:klass) { Class.new(ApplicationRecord).include(described_class) }

  describe '.admin_permission_enabled?' do
    let(:ability) { :read_admin_users }

    subject(:admin_permission_enabled) { klass.admin_permission_enabled?(ability) }

    where(:flag_exists, :flag_enabled, :expected_result) do
      true  | false | false
      true  | true  | true
      false | true  | true
    end

    with_them do
      before do
        if flag_exists
          stub_feature_flag_definition("custom_ability_read_admin_users")
          stub_feature_flags(custom_ability_read_admin_users: flag_enabled)
        end
      end

      context 'when the custom_admin_roles feature flag is disabled' do
        before do
          stub_feature_flags(custom_admin_roles: false)
        end

        it { is_expected.to be false }
      end

      context 'when the custom_admin_roles feature flag is enabled' do
        before do
          stub_feature_flags(custom_admin_roles: true)
        end

        it { is_expected.to eq(expected_result) }
      end
    end
  end
end
