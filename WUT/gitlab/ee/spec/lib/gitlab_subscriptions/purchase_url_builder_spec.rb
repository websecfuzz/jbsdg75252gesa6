# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::PurchaseUrlBuilder, feature_category: :subscription_management do
  describe '#build' do
    let(:subscription_portal_url) { Gitlab::Routing.url_helpers.subscription_portal_url }

    context 'when the plan is not supplied' do
      it 'generates the marketing page URL' do
        builder = described_class.new(plan_id: nil, namespace: nil)

        expect(builder.build).to eq "https://about.gitlab.com/pricing/"
      end
    end

    context 'when the namespace is not supplied' do
      it 'generates the subscription group path' do
        builder = described_class.new(plan_id: 'plan-id', namespace: nil)

        expect(builder.build).to eq "/-/subscriptions/groups/new?plan_id=plan-id"
      end
    end

    context 'when all purchase flow params are supplied' do
      let_it_be(:namespace) { create(:group) }

      subject(:builder) { described_class.new(plan_id: 'plan-id', namespace: namespace) }

      it 'generates the customers dot flow URL' do
        expect(builder.build)
          .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&plan_id=plan-id"
      end

      it 'includes any additional params in the URL' do
        expected_url = "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&" \
          "plan_id=plan-id&source=source"

        expect(builder.build(source: 'source')).to eq expected_url
      end
    end
  end
end
