# frozen_string_literal: true

require 'rubocop_spec_helper'

require_relative '../../../../rubocop/cop/usage_data/distinct_count_by_large_foreign_key'

RSpec.describe RuboCop::Cop::UsageData::DistinctCountByLargeForeignKey do
  let(:allowed_foreign_keys) { [:author_id, :user_id, :'merge_requests.target_project_id'] }
  let(:msg) { 'Avoid doing `distinct_count` on foreign keys for large tables having above 100 million rows.' }
  let(:config) do
    RuboCop::Config.new('UsageData/DistinctCountByLargeForeignKey' => {
      'AllowedForeignKeys' => allowed_foreign_keys
    })
  end

  context 'in an usage data file' do
    before do
      allow(cop).to receive(:in_usage_data_file?).and_return(true)
    end

    context 'when counting by disallowed key' do
      it 'registers an offense' do
        expect_offense(<<~RUBY)
          distinct_count(Issue, :creator_id)
          ^^^^^^^^^^^^^^ #{msg}
        RUBY
      end

      it 'does not register an offense when batch is false' do
        expect_no_offenses('distinct_count(Issue, :creator_id, batch: false)')
      end

      it 'registers an offense when batch is true' do
        expect_offense(<<~RUBY)
          distinct_count(Issue, :creator_id, batch: true)
          ^^^^^^^^^^^^^^ #{msg}
        RUBY
      end
    end

    context 'when calling by allowed key' do
      it 'does not register an offense with symbol' do
        expect_no_offenses('distinct_count(Issue, :author_id)')
      end

      it 'does not register an offense with string' do
        expect_no_offenses("distinct_count(Issue, 'merge_requests.target_project_id')")
      end
    end
  end

  context 'when outside of an usage data file' do
    it 'does not register an offense' do
      expect_no_offenses('distinct_count(Issue, :creator_id)')
    end
  end
end
