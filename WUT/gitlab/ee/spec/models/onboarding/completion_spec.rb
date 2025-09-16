# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::Completion, feature_category: :onboarding do
  let(:completed_actions) { {} }
  let(:project) { build(:project, namespace: namespace) }
  let!(:onboarding_progress) { create(:onboarding_progress, namespace: namespace, **completed_actions) }

  let_it_be(:namespace) { create(:namespace) }

  describe '#percentage' do
    let(:tracked_action_columns) do
      described_class::ACTION_PATHS.map do |key|
        ::Onboarding::Progress.column_name(key)
      end
    end

    subject(:percentage) { described_class.new(project).percentage }

    context 'when no onboarding_progress exists' do
      subject(:percentage) { described_class.new(build(:project)).percentage }

      it { is_expected.to eq(0) }
    end

    context 'when no action has been completed' do
      let(:repository_created_percentage) { 8 }

      it 'returns the created repository action as always completed' do
        is_expected.to eq(repository_created_percentage)
      end
    end

    context 'when all tracked actions have been completed' do
      let(:project) { build(:project, :stubbed_commit_count, namespace: namespace) }

      let(:completed_actions) do
        tracked_action_columns.index_with { Time.current }
      end

      it { is_expected.to eq(100) }
    end
  end

  describe '#completed?' do
    subject(:completed?) { described_class.new(project).completed?(column) }

    let(:column) { :code_added_at }
    let(:completed_actions) { { code_added_at: code_added_at_timestamp } }

    context 'when the action has been completed' do
      let(:code_added_at_timestamp) { Time.current }

      it { is_expected.to eq(true) }

      context 'when onboarding_progress is provided to initializer' do
        let(:column) { :code_added_at }
        let(:completed_actions) { { code_added_at: Time.current } }
        let(:onboarding_progress) { build(:onboarding_progress, **completed_actions) }

        subject(:completed?) do
          described_class.new(project, onboarding_progress: onboarding_progress).completed?(column)
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'when the action has not been completed' do
      let(:code_added_at_timestamp) { nil }

      it { is_expected.to eq(false) }
    end
  end
end
