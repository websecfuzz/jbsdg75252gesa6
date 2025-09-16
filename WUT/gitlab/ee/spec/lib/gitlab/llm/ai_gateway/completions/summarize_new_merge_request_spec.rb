# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::SummarizeNewMergeRequest, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let(:prompt_class) { Gitlab::Llm::Templates::SummarizeNewMergeRequest }
  let(:prompt_message) do
    build(:ai_message, :summarize_new_merge_request, user: user, resource: project, request_id: 'uuid')
  end

  let(:example_answer) { "AI generated merge request summary" }
  let(:example_response) { instance_double(HTTParty::Response, body: example_answer.to_json, success?: true) }

  subject(:summarize_new_merge_request) { described_class.new(prompt_message, prompt_class, options).execute }

  describe '#execute' do
    before do
      stub_feature_flags(ai_model_switching: false)
    end

    shared_examples 'makes AI request and publishes response' do
      it 'makes AI request and publishes response' do
        extracted_diff = Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
          source_project: options[:source_project] || project,
          source_branch: options[:source_branch],
          target_project: project,
          target_branch: options[:target_branch],
          character_limit: described_class::CHARACTER_LIMIT
        )

        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :summarize_new_merge_request,
              inputs: { extracted_diff: extracted_diff },
              model_metadata: nil,
              prompt_version: "^2.0.0"
            )
            .and_return(example_response)
        end

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
        expect(summarize_new_merge_request[:ai_message].content).to eq(example_answer)
      end
    end

    context 'with valid source branch and project' do
      let(:options) do
        {
          source_branch: 'feature',
          target_branch: project.default_branch,
          source_project: project
        }
      end

      it_behaves_like 'makes AI request and publishes response'
    end

    context 'when extracted diff is blank' do
      let(:options) do
        {
          source_branch: 'does-not-exist',
          target_branch: project.default_branch,
          source_project: project
        }
      end

      it 'does not make an AI request and returns nil' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)
        expect(summarize_new_merge_request).to be_nil
      end
    end

    context 'when source_project_id is invalid' do
      let(:options) do
        {
          source_branch: 'feature',
          target_branch: project.default_branch,
          source_project_id: non_existing_record_id
        }
      end

      it_behaves_like 'makes AI request and publishes response'
    end
  end

  describe '#root_namespace' do
    let(:options) do
      {
        source_branch: 'feature',
        target_branch: project.default_branch,
        source_project: project
      }
    end

    let(:completion_instance) { described_class.new(prompt_message, prompt_class, options) }

    context 'when project has a root ancestor' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, :repository, namespace: subgroup) }

      it 'returns the root ancestor of the project' do
        expect(completion_instance.root_namespace).to eq(group)
      end
    end

    context 'when project is at root level' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :repository, namespace: group) }

      it 'returns the group itself' do
        expect(completion_instance.root_namespace).to eq(group)
      end
    end

    context 'when project belongs to a user namespace' do
      let_it_be(:project) { create(:project, :repository) }

      it 'returns the user namespace as root ancestor' do
        expect(completion_instance.root_namespace).to eq(project.root_namespace)
      end
    end
  end

  describe 'namespace feature setting integration' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, namespace: group) }

    let(:options) do
      {
        source_branch: 'feature',
        target_branch: project.default_branch,
        source_project: project
      }
    end

    before do
      stub_feature_flags(ai_model_switching: true)
    end

    context 'when namespace has specific feature settings' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'summarize_new_merge_request',
          offered_model_ref: 'claude_sonnet_3_7_20250219',
          offered_model_name: 'Claude Sonnet 3.7 20250219')
      end

      it 'uses namespace-specific model settings' do
        extracted_diff = Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: project.default_branch,
          character_limit: described_class::CHARACTER_LIMIT
        )

        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :summarize_new_merge_request,
              inputs: { extracted_diff: extracted_diff },
              model_metadata: hash_including(
                feature_setting: 'summarize_new_merge_request',
                identifier: 'claude_sonnet_3_7_20250219',
                provider: 'gitlab'
              ),
              prompt_version: '^2.0.0'
            )
            .and_return(example_response)
        end

        summarize_new_merge_request
      end
    end

    context 'when namespace has no specific feature settings' do
      let!(:standard_feature_setting) do
        create(:ai_feature_setting,
          feature: 'summarize_new_merge_request',
          provider: :vendored)
      end

      it 'falls back to default gitlab settings' do
        extracted_diff = Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: project.default_branch,
          character_limit: described_class::CHARACTER_LIMIT
        )

        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :summarize_new_merge_request,
              inputs: { extracted_diff: extracted_diff },
              model_metadata: hash_including(
                feature_setting: 'summarize_new_merge_request',
                identifier: nil,
                provider: 'gitlab'
              ),
              prompt_version: '^2.0.0'
            )
            .and_return(example_response)
        end

        summarize_new_merge_request
      end
    end

    context 'when project is in a subgroup' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, :repository, namespace: subgroup) }

      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group, # Setting on root group, not subgroup
          feature: 'summarize_new_merge_request',
          offered_model_ref: 'claude_sonnet_3_7_20250219',
          offered_model_name: 'Claude Sonnet 3.7 20250219')
      end

      it 'uses root namespace feature settings' do
        extracted_diff = Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
          source_project: project,
          source_branch: 'feature',
          target_project: project,
          target_branch: project.default_branch,
          character_limit: described_class::CHARACTER_LIMIT
        )

        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :summarize_new_merge_request,
              inputs: { extracted_diff: extracted_diff },
              model_metadata: hash_including(
                feature_setting: 'summarize_new_merge_request',
                identifier: 'claude_sonnet_3_7_20250219',
                provider: 'gitlab'
              ),
              prompt_version: '^2.0.0'
            )
            .and_return(example_response)
        end

        summarize_new_merge_request
      end
    end
  end
end
