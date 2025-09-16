# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::VulnerabilitiesOverTimeResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    resolve(described_class, obj: operate_on, args: args, ctx: { current_user: current_user })
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  describe '#resolve' do
    let(:start_date) { Date.new(2019, 10, 15) }
    let(:end_date) { Date.new(2019, 10, 21) }
    let(:args) { { start_date: start_date, end_date: end_date } }

    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(group_security_dashboard_new: true)
    end

    context 'when operated on a group' do
      let(:operate_on) { group }

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        it 'returns vulnerability metrics data' do
          expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
          expect(resolved_metrics.items).not_to be_empty
        end

        context 'with filter arguments' do
          let(:args) do
            {
              start_date: start_date,
              end_date: end_date,
              project_id: [project.to_global_id.to_s],
              severity: ['critical'],
              scanner: ['sast']
            }
          end

          it 'returns filtered vulnerability metrics' do
            expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
            expect(resolved_metrics.items).not_to be_empty
          end
        end
      end

      context 'when the current user does not have access' do
        it 'returns a resource not available error' do
          expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when group_security_dashboard_new feature flag is disabled' do
        before do
          stub_feature_flags(group_security_dashboard_new: false)
        end

        before_all do
          group.add_maintainer(current_user)
        end

        it 'returns an empty connection' do
          expect(resolved_metrics).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
          expect(resolved_metrics.items).to be_empty
        end
      end
    end

    context 'when security_dashboard feature flag is disabled' do
      let(:operate_on) { group }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns a resource not available error' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end

  describe '#validate_date_range' do
    let(:operate_on) { group }

    before_all do
      group.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
      stub_feature_flags(group_security_dashboard_new: true)
    end

    context 'when start_date is after end_date' do
      let(:start_date) { Date.new(2019, 10, 21) }
      let(:end_date) { Date.new(2019, 10, 15) }
      let(:args) { { start_date: start_date, end_date: end_date } }

      it 'returns an ArgumentError' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        expect(resolved_metrics.message).to eq('start date cannot be after end date')
      end
    end

    context 'when date range exceeds maximum allowed days' do
      let(:start_date) { Date.current }
      let(:end_date) { start_date + (described_class::MAX_DATE_RANGE_DAYS + 1).days }
      let(:args) { { start_date: start_date, end_date: end_date } }

      it 'returns an ArgumentError' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ArgumentError)
        expect(resolved_metrics.message).to eq("maximum date range is #{described_class::MAX_DATE_RANGE_DAYS} days")
      end
    end
  end
end
