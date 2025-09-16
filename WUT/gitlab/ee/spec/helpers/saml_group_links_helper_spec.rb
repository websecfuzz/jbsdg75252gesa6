# frozen_string_literal: true

require "spec_helper"

RSpec.describe SamlGroupLinksHelper, feature_category: :system_access do
  include LoginHelpers

  describe '#saml_group_link_input_names' do
    subject(:saml_group_link_input_names) { helper.saml_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "saml_group_link[access_level]",
        member_role_id_input_name: "saml_group_link[member_role_id]"
      }

      expect(saml_group_link_input_names).to match(hash_including(expected_data))
    end
  end

  describe '#duo_seat_assignment_available?' do
    let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects

    subject(:duo_seat_assignment_available?) { helper.duo_seat_assignment_available?(group) }

    it { is_expected.to be false }

    context 'when SaaS feature is available' do
      before do
        stub_saas_features(gitlab_duo_saas_only: true)
      end

      it { is_expected.to be false }

      context 'when there is an active add-on subscription' do
        let_it_be(:add_on_purchase) do
          create( # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
            :gitlab_subscription_add_on_purchase,
            :duo_pro,
            expires_on: 1.week.from_now.to_date,
            namespace: group
          )
        end

        it { is_expected.to be true }

        context 'when group is a subgroup' do
          let_it_be(:parent_group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects

          before_all do
            group.update!(parent: parent_group)
          end

          it { is_expected.to be false }
        end

        context 'when the subscription is not active' do
          before_all do
            add_on_purchase.update!(expires_on: 1.week.ago.to_date)
          end

          it { is_expected.to be false }
        end
      end
    end
  end

  shared_context 'with single SAML provider' do
    let(:saml_provider_1) { Struct.new(:name, :label, :args).new('saml', 'Default SAML', {}) }

    before do
      stub_omniauth_config(providers: [saml_provider_1])
    end
  end

  shared_context 'with multiple SAML providers' do
    let(:saml_provider_1) { Struct.new(:name, :label, :args).new('saml', 'Default SAML', {}) }
    let(:saml_provider_2) do
      Struct.new(:name, :label, :args).new('saml2', 'SAML 2', { 'strategy_class' => 'OmniAuth::Strategies::SAML' })
    end

    before do
      stub_omniauth_config(providers: [saml_provider_1, saml_provider_2])
    end
  end

  describe '#multiple_saml_providers?' do
    subject(:multiple_saml_providers) { helper.multiple_saml_providers? }

    context 'with single provider' do
      include_context 'with single SAML provider'

      it { is_expected.to be false }
    end

    context 'with multiple providers' do
      include_context 'with multiple SAML providers'

      it { is_expected.to be true }
    end
  end

  describe '#saml_providers_for_dropdown' do
    subject(:saml_providers_for_dropdown) { helper.saml_providers_for_dropdown }

    context 'with single provider' do
      include_context 'with single SAML provider'

      it { is_expected.to contain_exactly(['Default SAML', 'saml']) }
    end

    context 'with multiple providers' do
      include_context 'with multiple SAML providers'

      it { is_expected.to contain_exactly(['Default SAML', 'saml'], ['SAML 2', 'saml2']) }
    end
  end
end
