# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettings::FeatureSettingFinder, feature_category: :"self-hosted_models" do
  let_it_be(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2
    }
  end

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:existing_feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :duo_chat,
      provider: :self_hosted
    )
  end

  before do
    allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(test_ai_feature_enum)
  end

  subject(:execute_finder) { described_class.new(**args).execute }

  describe '#execute' do
    context 'when no argument is provided' do
      let(:args) { {} }

      let(:expected_results) do
        test_ai_feature_enum.keys.map do |feature|
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end

      it 'returns all the feature settings with the uninitialized ones', :aggregate_failures do
        results = execute_finder

        # Testing attributes because uninitialized instances never have the same ref even with same values
        expect(results.map(&:id)).to match_array(expected_results.map(&:id))
        expect(results.map(&:feature)).to match_array(expected_results.map(&:feature))
        expect(results.map(&:provider)).to match_array(expected_results.map(&:provider))
        expect(results.map(&:self_hosted_model)).to match_array(expected_results.map(&:self_hosted_model))
      end
    end

    context 'when a self_hosted_model_id argument is provided' do
      let(:args) { { self_hosted_model_id: self_hosted_model } }
      let(:expected_results) { [existing_feature_setting] }

      context 'with an existing self-hosted model' do
        it 'only returns the settings belonging to self-hosted model' do
          expect(execute_finder).to match_array(expected_results)
        end
      end

      context 'with an non-existing self-hosted model' do
        let(:args) { { self_hosted_model_id: non_existing_record_id } }

        it 'returns an empty array' do
          expect(execute_finder).to be_empty
        end
      end
    end
  end
end
