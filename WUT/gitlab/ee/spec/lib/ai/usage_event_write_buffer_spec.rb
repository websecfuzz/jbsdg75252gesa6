# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEventWriteBuffer, feature_category: :database do
  it_behaves_like 'using redis backwards compatible methods' do
    let(:buffer_key) { "usage_event_write_buffer_test_model" }
  end
end
