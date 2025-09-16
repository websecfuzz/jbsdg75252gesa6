# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::ApplicationRateLimiter, feature_category: :system_access do
  describe '.rate_limits' do
    subject(:rate_limits) { Gitlab::ApplicationRateLimiter.rate_limits }

    context 'when application-level rate limits are configured' do
      using RSpec::Parameterized::TableSyntax

      before do
        stub_application_setting(max_number_of_repository_downloads: 1)
        stub_application_setting(max_number_of_repository_downloads_within_time_period: 60)
        stub_application_setting(soft_phone_verification_transactions_daily_limit: 60)
        stub_application_setting(hard_phone_verification_transactions_daily_limit: 100)
      end

      where(:key, :threshold, :interval) do
        :unique_project_downloads_for_application | 1 | 1.minute
        :code_suggestions_api_endpoint | 60 | 1.minute
        :code_suggestions_direct_access | 50 | 1.minute
        :code_suggestions_x_ray_scan | 60 | 1.minute
        :code_suggestions_x_ray_dependencies | 60 | 1.minute
        :duo_workflow_direct_access | 50 | 1.minute
        :soft_phone_verification_transactions_limit | 60 | 1.day
        :hard_phone_verification_transactions_limit | 100 | 1.day
        :virtual_registries_endpoints_api_limit | 1000 | 15.seconds
      end

      with_them do
        it "includes values for #{params[:key]}" do
          values = rate_limits[key]

          expect(call_or_value(values[:threshold])).to eq threshold
          expect(call_or_value(values[:interval])).to eq interval
        end

        def call_or_value(value)
          return value.to_i unless value.is_a?(Proc)

          value.call
        end
      end
    end

    context 'when namespace-level rate limits are configured' do
      it 'includes fixed default values for unique_project_downloads_for_namespace', :aggregate_failures do
        values = rate_limits[:unique_project_downloads_for_namespace]
        expect(values[:threshold]).to eq 0
        expect(values[:interval]).to eq 0
      end

      it 'includes fixed default values for soft_phone_verification_transactions_limit' do
        values = rate_limits[:soft_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 16000, interval: 1.day)
      end

      it 'includes fixed default values for hard_phone_verification_transactions_limit' do
        values = rate_limits[:hard_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 20000, interval: 1.day)
      end
    end
  end
end
