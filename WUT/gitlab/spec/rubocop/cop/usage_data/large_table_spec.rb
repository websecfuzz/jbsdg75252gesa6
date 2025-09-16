# frozen_string_literal: true

require 'rubocop_spec_helper'

require_relative '../../../../rubocop/cop/usage_data/large_table'

RSpec.describe RuboCop::Cop::UsageData::LargeTable do
  let(:large_tables) { %i[Rails Time] }
  let(:count_methods) { %i[count distinct_count] }
  let(:allowed_methods) { %i[minimum maximum] }
  let(:msg) { 'Use one of the count, distinct_count methods for counting on' }

  let(:config) do
    RuboCop::Config.new('UsageData/LargeTable' => {
      'NonRelatedClasses' => large_tables,
      'CountMethods' => count_methods,
      'AllowedMethods' => allowed_methods
    })
  end

  context 'in an usage data file' do
    before do
      allow(cop).to receive(:in_usage_data_file?).and_return(true)
    end

    context 'with large tables' do
      context 'when calling Issue.count' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Issue.count
            ^^^^^^^^^^^ #{msg} Issue
          RUBY
        end
      end

      context 'when calling Issue.active.count' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Issue.active.count
            ^^^^^^^^^^^^ #{msg} Issue
          RUBY
        end
      end

      context 'when calling count(Issue)' do
        it 'does not register an offense' do
          expect_no_offenses('count(Issue)')
        end
      end

      context 'when calling count(Ci::Build.active)' do
        it 'does not register an offense' do
          expect_no_offenses('count(Ci::Build.active)')
        end
      end

      context 'when calling Ci::Build.active.count' do
        it 'registers an offense' do
          expect_offense(<<~RUBY)
            Ci::Build.active.count
            ^^^^^^^^^^^^^^^^ #{msg} Ci::Build
          RUBY
        end
      end

      context 'when using allowed methods' do
        it 'does not register an offense' do
          expect_no_offenses('Issue.minimum')
        end
      end
    end

    context 'with non related class' do
      it 'does not register an offense' do
        expect_no_offenses('Rails.count')
      end
    end
  end

  context 'when outside of an usage data file' do
    it 'does not register an offense' do
      expect_no_offenses('Issue.active.count')
    end
  end
end
