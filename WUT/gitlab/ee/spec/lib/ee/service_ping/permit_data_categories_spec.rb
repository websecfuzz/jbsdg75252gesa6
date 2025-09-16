# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServicePing::PermitDataCategories, feature_category: :service_ping do
  describe '#execute' do
    subject(:permitted_categories) { described_class.new.execute }

    context 'with out current license', :without_license do
      context 'when usage ping setting is set to true' do
        it 'returns all categories' do
          stub_config_setting(usage_ping_enabled: true)

          expect(permitted_categories).to match_array(%w[standard subscription operational optional])
        end
      end

      context 'when usage ping setting is set to false' do
        it 'returns all categories' do
          stub_config_setting(usage_ping_enabled: false)

          expect(permitted_categories).to match_array(%w[standard subscription operational optional])
        end
      end
    end

    context 'with current license' do
      using RSpec::Parameterized::TableSyntax

      where(:usage_ping_enabled, :operational_metrics_enabled, :optional_metrics_enabled, :expected_data_categories) do
        false | false | false | %w[standard subscription operational]
        true  | false | false | %w[standard subscription operational]
        true  | false | true  | %w[standard subscription operational optional]
        true  | true  | false | %w[standard subscription operational]
        true  | true  | true  | %w[standard subscription operational optional]
        false | true  | true  | %w[standard subscription operational optional]
        false | true  | false | %w[standard subscription operational]
      end

      with_them do
        before do
          stub_config_setting(usage_ping_enabled: usage_ping_enabled)
          create_current_license(operational_metrics_enabled: operational_metrics_enabled)
          stub_application_setting(include_optional_metrics_in_service_ping: optional_metrics_enabled)
        end

        it 'returns expected categories' do
          expect(permitted_categories).to match_array(expected_data_categories)
        end
      end

      context 'when usage ping setting is set to true' do
        before do
          stub_config_setting(usage_ping_enabled: true)
        end

        context 'and license has operational_metrics_enabled set to true' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: true)
          end

          it 'returns all categories' do
            expect(permitted_categories).to match_array(%w[standard subscription operational optional])
          end

          context 'when User.single_user&.requires_usage_stats_consent? is required' do
            before do
              allow(User).to receive(:single_user)
                .and_return(instance_double(User, :user, requires_usage_stats_consent?: true))
            end

            it 'returns all categories' do
              expect(permitted_categories).to match_array(%w[standard subscription operational optional])
            end
          end
        end

        context 'and license has operational_metrics_enabled set to false' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: false)
          end

          it 'returns all categories' do
            expect(permitted_categories).to match_array(%w[standard subscription operational optional])
          end
        end
      end

      context 'when usage ping setting is set to false' do
        before do
          stub_config_setting(usage_ping_enabled: false)
        end

        context 'and license has operational_metrics_enabled set to true' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: true)
            allow(ServicePing::ServicePingSettings).to receive(:enabled_and_consented?).and_return(true)
          end

          it 'returns all categories' do
            expect(permitted_categories).to match_array(%w[standard subscription operational optional])
          end
        end

        context 'and license has operational_metrics_enabled set to false' do
          before do
            # License.current.usage_ping? == true
            create_current_license(operational_metrics_enabled: false)
          end

          it 'returns all categories' do
            expect(permitted_categories).to match_array(%w[standard subscription operational optional])
          end
        end
      end
    end
  end
end
