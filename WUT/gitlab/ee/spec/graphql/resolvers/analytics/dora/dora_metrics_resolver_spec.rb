# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::Dora::DoraMetricsResolver, time_travel_to: '2021-05-01', feature_category: :dora_metrics do
  include GraphqlHelpers

  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:production) { create(:environment, :production, project: project) }
  let_it_be(:staging) { create(:environment, :staging, project: project) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }

  let(:number_of_days) { (Time.current.to_date - 3.months.ago.to_date).to_i + 1 }

  let(:current_user) { reporter }

  before_all do
    create(:dora_daily_metrics, deployment_frequency: 20, environment: production, date: '2020-01-01')
    create(:dora_daily_metrics, deployment_frequency: 19, environment: production, date: '2021-01-01')
    create(:dora_daily_metrics, deployment_frequency: 18, environment: production, date: '2021-03-01')
    create(:dora_daily_metrics, deployment_frequency: 17, environment: production, date: '2021-04-01')
    create(:dora_daily_metrics, deployment_frequency: 16, environment: production, date: '2021-04-02')
    create(:dora_daily_metrics, deployment_frequency: 15, environment: production, date: '2021-04-03')
    create(:dora_daily_metrics, deployment_frequency: 14, environment: production, date: '2021-04-04')
    create(:dora_daily_metrics, deployment_frequency: 13, environment: production, date: '2021-04-05')
    create(:dora_daily_metrics, deployment_frequency: 12, environment: production, date: '2021-04-06')
    create(:dora_daily_metrics, deployment_frequency: nil, environment: production, date: '2021-04-07')
    create(:dora_daily_metrics, deployment_frequency: 11, environment: production, date: '2021-05-06')

    create(:dora_daily_metrics, deployment_frequency: 10, environment: staging, date: '2021-04-01')
    create(:dora_daily_metrics, deployment_frequency: nil, environment: staging, date: '2021-04-02')
  end

  before do
    stub_licensed_features(dora4_analytics: true)
  end

  shared_examples 'dora metrics' do
    describe '#resolve' do
      let(:args) { {} }

      subject { resolve_metrics }

      context 'when the user has no access to DORA metrics' do
        let(:current_user) { guest }

        it { is_expected.to be_nil }
      end

      context 'when DORA metrics are not licensed' do
        before do
          stub_licensed_features(dora4_analytics: false)
        end

        it { is_expected.to be_nil }
      end

      it 'returns metrics from production for the last 3 months from the production environment, grouped by day' do
        expect(resolve_metrics).to eq(
          [
            *empty_metric_rows(from: '2021-02-01', to: '2021-02-28'),
            metric_row('date' => '2021-03-01', 'deployment_frequency' => 18),
            *empty_metric_rows(from: '2021-03-02', to: '2021-03-31'),
            metric_row('date' => '2021-04-01', 'deployment_frequency' => 17),
            metric_row('date' => '2021-04-02', 'deployment_frequency' => 16),
            metric_row('date' => '2021-04-03', 'deployment_frequency' => 15),
            metric_row('date' => '2021-04-04', 'deployment_frequency' => 14),
            metric_row('date' => '2021-04-05', 'deployment_frequency' => 13),
            metric_row('date' => '2021-04-06', 'deployment_frequency' => 12),
            metric_row('date' => '2021-04-07', 'deployment_frequency' => nil),
            *empty_metric_rows(from: '2021-04-08', to: '2021-05-01')
          ])
      end

      context 'with interval: "daily"' do
        let(:args) { { interval: 'daily' } }

        it 'returns the metrics grouped by day (the default)' do
          expect(resolve_metrics).to eq(
            [
              *empty_metric_rows(from: '2021-02-01', to: '2021-02-28'),
              metric_row('date' => '2021-03-01', 'deployment_frequency' => 18),
              *empty_metric_rows(from: '2021-03-02', to: '2021-03-31'),
              metric_row('date' => '2021-04-01', 'deployment_frequency' => 17),
              metric_row('date' => '2021-04-02', 'deployment_frequency' => 16),
              metric_row('date' => '2021-04-03', 'deployment_frequency' => 15),
              metric_row('date' => '2021-04-04', 'deployment_frequency' => 14),
              metric_row('date' => '2021-04-05', 'deployment_frequency' => 13),
              metric_row('date' => '2021-04-06', 'deployment_frequency' => 12),
              metric_row('date' => '2021-04-07', 'deployment_frequency' => nil),
              *empty_metric_rows(from: '2021-04-08', to: '2021-05-01')
            ])
        end
      end

      context 'with interval: "monthly"' do
        let(:args) { { interval: 'monthly' } }

        it 'returns the metrics grouped by month' do
          deployments_in_march = 18
          deployments_in_april = 87
          days_in_march = 31
          days_in_april = 30

          expect(resolve_metrics).to eq(
            [
              *empty_metric_rows(from: '2021-02-01', to: '2021-02-01'),
              metric_row('date' => '2021-03-01', 'deployment_frequency' => deployments_in_march.fdiv(days_in_march)),
              metric_row('date' => '2021-04-01', 'deployment_frequency' => deployments_in_april.fdiv(days_in_april)),
              *empty_metric_rows(from: '2021-05-01', to: '2021-05-01')
            ])
        end
      end

      context 'with interval: "all"' do
        let(:args) { { interval: 'all' } }

        it 'returns the metrics grouped into a single bucket with a nil date' do
          expect(resolve_metrics).to eq(
            [
              metric_row('date' => nil, 'deployment_frequency' => 105.fdiv(number_of_days))
            ])
        end
      end

      context 'with a start_date' do
        let(:args) { { start_date: '2021-04-03'.to_datetime } }

        it 'returns metrics for data on or after the provided date' do
          expect(resolve_metrics).to eq(
            [
              metric_row('date' => '2021-04-03', 'deployment_frequency' => 15),
              metric_row('date' => '2021-04-04', 'deployment_frequency' => 14),
              metric_row('date' => '2021-04-05', 'deployment_frequency' => 13),
              metric_row('date' => '2021-04-06', 'deployment_frequency' => 12),
              metric_row('date' => '2021-04-07', 'deployment_frequency' => nil),
              *empty_metric_rows(from: '2021-04-08', to: '2021-05-01')
            ])
        end
      end

      context 'with an end_date' do
        let(:args) { { end_date: '2021-04-03'.to_datetime } }

        it 'returns metrics for data on or before the provided date' do
          expect(resolve_metrics).to eq(
            [
              *empty_metric_rows(from: '2021-02-01', to: '2021-02-28'),
              metric_row('date' => '2021-03-01', 'deployment_frequency' => 18),
              *empty_metric_rows(from: '2021-03-02', to: '2021-03-31'),
              metric_row('date' => '2021-04-01', 'deployment_frequency' => 17),
              metric_row('date' => '2021-04-02', 'deployment_frequency' => 16),
              metric_row('date' => '2021-04-03', 'deployment_frequency' => 15)
            ])
        end
      end

      context 'with both a start_date and an end_date' do
        let(:args) { { start_date: '2021-04-01'.to_datetime, end_date: '2021-04-03'.to_datetime } }

        it 'returns metrics between the provided dates (inclusive)' do
          expect(resolve_metrics).to eq(
            [
              metric_row('date' => '2021-04-01', 'deployment_frequency' => 17),
              metric_row('date' => '2021-04-02', 'deployment_frequency' => 16),
              metric_row('date' => '2021-04-03', 'deployment_frequency' => 15)
            ])
        end
      end

      context 'when the requested date range is too large' do
        let(:args) { { start_date: '2020-01-01'.to_datetime, end_date: '2021-05-01'.to_datetime } }

        it 'generates an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
            'Date range must be shorter than 180 days.') do
            resolve_metrics
          end
        end
      end

      context 'when the start date equal to or later than the end date' do
        let(:args) { { start_date: '2021-04-01'.to_datetime, end_date: '2021-03-01'.to_datetime } }

        it 'generates an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
            'The start date must be earlier than the end date.') do
            resolve_metrics
          end
        end
      end

      context 'with multiple environment_tiers' do
        let(:args) { { environment_tiers: %w[production staging] } }

        it 'returns metrics for all environments combined' do
          expect(resolve_metrics).to eq(
            [
              *empty_metric_rows(from: '2021-02-01', to: '2021-02-28'),
              metric_row('date' => '2021-03-01', 'deployment_frequency' => 18),
              *empty_metric_rows(from: '2021-03-02', to: '2021-03-31'),
              metric_row('date' => '2021-04-01', 'deployment_frequency' => 27),
              metric_row('date' => '2021-04-02', 'deployment_frequency' => 16),
              metric_row('date' => '2021-04-03', 'deployment_frequency' => 15),
              metric_row('date' => '2021-04-04', 'deployment_frequency' => 14),
              metric_row('date' => '2021-04-05', 'deployment_frequency' => 13),
              metric_row('date' => '2021-04-06', 'deployment_frequency' => 12),
              metric_row('date' => '2021-04-07', 'deployment_frequency' => nil),
              *empty_metric_rows(from: '2021-04-08', to: '2021-05-01')
            ])
        end
      end
    end
  end

  context 'when the user is querying for project-level metrics' do
    let(:obj) { project }

    it_behaves_like 'dora metrics'
  end

  context 'when the user is querying for group-level metrics' do
    let(:obj) { group }

    it_behaves_like 'dora metrics'
  end

  private

  def resolve_metrics
    context = { current_user: current_user }
    response = resolve(described_class, obj: obj, lookahead: positive_lookahead, args: args, ctx: context,
      arg_style: :internal)
    response.each { |row| row.delete('deployment_count') } if response.is_a?(Array) # not used in GraphQL
    response
  end

  def metric_row(**extra)
    row = ::Dora::DailyMetrics::AVAILABLE_METRICS.index_with { |_key| nil }.merge(extra)
    row['date'] = Date.parse(row['date']) if row['date'].is_a?(String)
    row
  end

  def empty_metric_rows(from:, to:)
    empty_rows = []

    (from.to_date..to.to_date).step(1) do |date|
      empty_rows << metric_row('date' => date)
    end

    empty_rows
  end
end
