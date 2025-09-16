# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoCore, feature_category: :'add-on_provisioning' do
  describe '.any_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(false) }
    end
  end

  describe '.available?' do
    using RSpec::Parameterized::TableSyntax

    let(:user) { build(:user) }
    let(:namespace) { build(:namespace) }

    subject { described_class.available?(user, namespace) }

    where(:gitlab_duo_saas_only, :can_access, :with_namespace, :expected_result) do
      true  | true  | true  | true
      true  | false | true  | false
      false | true  | false | true
      false | false | false | false
    end

    with_them do
      before do
        stub_saas_features(gitlab_duo_saas_only: gitlab_duo_saas_only)

        if with_namespace
          allow(user).to receive(:can?).with(:access_duo_core_features, namespace).and_return(can_access)
        else
          allow(user).to receive(:can?).with(:access_duo_core_features).and_return(can_access)
        end
      end

      it 'returns the expected result' do
        is_expected.to eq(expected_result)
      end
    end
  end
end
