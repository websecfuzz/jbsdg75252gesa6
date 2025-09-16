# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::GitlabDedicatedMetric, feature_category: :service_ping do
  let(:expected_value) { Gitlab::CurrentSettings.gitlab_dedicated_instance }

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
end
