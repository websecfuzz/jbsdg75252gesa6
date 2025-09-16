# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::UpstreamPolicy, feature_category: :virtual_registry do
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

  let(:user) { upstream.group.first_owner }

  let(:policy) { described_class.new(user, upstream) }

  describe 'delegation' do
    subject { policy.delegated_policies.values }

    it { is_expected.to have_attributes(size: 1).and be_all(::VirtualRegistries::Packages::Policies::GroupPolicy) }
  end
end
