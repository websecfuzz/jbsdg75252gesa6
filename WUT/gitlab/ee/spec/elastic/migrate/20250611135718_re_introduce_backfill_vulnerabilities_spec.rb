# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250611135718_re_introduce_backfill_vulnerabilities.rb')

RSpec.describe ReIntroduceBackfillVulnerabilities, feature_category: :vulnerability_management do
  let(:version) { 20250611135718 }

  describe 'migration', :elastic do
    it_behaves_like 'migration reindexes all data' do
      let(:objects) { create_list(:vulnerability_read, 3) }
      let(:factory_to_create_objects) { :vulnerability_read }
      let(:expected_throttle_delay) { 30.seconds }
      let(:expected_batch_size) { 30_000 }
    end
  end
end
