# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::DuoCoreFeaturesEnabledMetric, feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  where(:duo_core_features_enabled, :expected_value) do
    false | false
    true  | true
    nil   | nil
  end

  with_them do
    before do
      create(:ai_settings, duo_core_features_enabled: duo_core_features_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
