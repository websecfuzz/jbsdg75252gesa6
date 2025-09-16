# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::GenerateCubeQuery, feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user) }

  let(:prompt_class) { Gitlab::Llm::VertexAi::Templates::GenerateCubeQuery }
  let(:options) { { question: "How many people used the application this week?" } }
  let(:prompt_message) do
    build(:ai_message, :generate_cube_query, user: user, resource: project, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(prompt_message, prompt_class, options) }

  describe '#execute' do
    context 'when the text client returns a successful response' do
      let(:example_answer) { 'XXXXX' }

      let(:example_response) do
        {
          "predictions" => [
            {
              "candidates" => [
                {
                  "author" => "",
                  "content" => example_answer
                }
              ],
              "safetyAttributes" => {
                "categories" => ["Violent"],
                "scores" => [0.4000000059604645],
                "blocked" => false
              }
            }
          ]
        }
      end

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
          allow(client).to receive(:code).and_return(example_response.to_json)
        end
      end

      it 'calls the GraphQL response service' do
        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).once.and_call_original

        completion.execute
      end
    end
  end
end
