# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationPolicy, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user) }

  subject(:policy) { described_class.new(current_user, organization) }

  RSpec.shared_context 'with licensed features' do |features|
    before do
      stub_licensed_features(features)
    end
  end

  context 'when the user is an admin' do
    let_it_be(:current_user) { create(:user, :admin) }

    context 'when admin mode is enabled', :enable_admin_mode do
      context 'when dependency scanning is enabled' do
        include_context 'with licensed features', dependency_scanning: true

        it { is_expected.to be_allowed(:read_dependency) }
      end

      context 'when license scanning is enabled' do
        include_context 'with licensed features', license_scanning: true

        it { is_expected.to be_allowed(:read_licenses) }
      end

      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end

    context 'when admin mode is disabled' do
      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end
  end

  context 'when the user is an organization owner' do
    let_it_be(:organization_user) { create(:organization_user, :owner, organization: organization, user: current_user) }

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  context 'when the user is an organization guest' do
    let_it_be(:organization_user) do
      create(:organization_user, organization: organization, user: current_user, access_level: :default)
    end

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  context 'when the user is not a member of the organization' do
    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end
end
