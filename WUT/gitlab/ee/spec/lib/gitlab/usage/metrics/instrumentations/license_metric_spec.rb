# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::LicenseMetric, feature_category: :plan_provisioning do
  let(:current_license) { ::License.current }

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'trial?' } } do
    let(:expected_value) { current_license.trial? }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'license_id' } } do
    let(:expected_value) { current_license.license_id }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'expires_at' } } do
    let(:expected_value) { current_license.expires_at }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'trial_ends_on' } } do
    let(:expected_value) { ::License.trial_ends_on }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'plan' } } do
    let(:expected_value) { current_license.plan }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'subscription_id' } } do
    let(:expected_value) { current_license.subscription_id }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'starts_at' } } do
    let(:expected_value) { current_license.starts_at }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'user_count' } } do
    let(:expected_value) { current_license.seats }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', options: { attribute: 'daily_billable_users_count' } } do
    let(:expected_value) { current_license.daily_billable_users_count }
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'add_ons' } } do
    let(:expected_value) { current_license.add_ons }
  end

  context 'without a valid license' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:unparsable_license) do
      data = Gitlab::License::Encryptor
        .new(OpenSSL::PKey::RSA.generate(3072))
        .encrypt(Gitlab::License.new.to_json)

      build(:license, data: data)
    end

    where(:attribute, :timeframe) do
      'trial?'                     | 'none'
      'license_id'                 | 'none'
      'expires_at'                 | 'none'
      'trial_ends_on'              | 'none'
      'plan'                       | 'none'
      'subscription_id'            | 'none'
      'starts_at'                  | 'none'
      'user_count'                 | 'none'
      'daily_billable_users_count' | 'all'
      'add_ons'                    | 'none'
    end

    with_them do
      let(:expected_value) { nil }

      context 'when the license is unparsable' do
        before do
          allow(::License).to receive(:current).and_return(unparsable_license)
        end

        it_behaves_like 'a correct instrumented metric value', {} do
          let(:time_frame) { timeframe }
          let(:options) { { attribute: attribute } }
        end
      end

      context 'when the license is absent', :without_license do
        it_behaves_like 'a correct instrumented metric value', {} do
          let(:time_frame) { timeframe }
          let(:options) { { attribute: attribute } }
        end
      end
    end

    context 'for license info not stored on the unparsable license' do
      let(:expected_value) { 1.week.from_now.to_date }

      before do
        allow(::License).to receive(:current).and_return(unparsable_license)
        allow(Gitlab::CurrentSettings).to receive(:license_trial_ends_on).and_return(expected_value)
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'none', options: { attribute: 'trial_ends_on' } }
    end
  end
end
