# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Templates::DescriptionComposer, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:previous_response) { '' }

  let(:params) do
    {
      description: 'Client merge request description',
      user_prompt: 'Hello world from user prompt',
      title: merge_request.title,
      source_branch: merge_request.source_branch,
      target_branch: merge_request.target_branch,
      previous_response: previous_response
    }
  end

  subject(:template) { described_class.new(user, project, params) }

  describe '#to_prompt' do
    it 'includes raw diff' do
      diff_file = merge_request.raw_diffs.to_a[0]

      expect(template.to_prompt[:messages][0][:content]).to include(diff_file.diff.split("\n")[1])
    end

    it 'includes merge request title' do
      expect(template.to_prompt[:messages][0][:content]).to include(merge_request.title)
    end

    it 'includes user prompt' do
      expect(template.to_prompt[:messages][0][:content]).to include('Hello world from user prompt')
    end

    it 'includes description sent from client' do
      expect(template.to_prompt[:messages][0][:content]).to include('Client merge request description')
    end

    context 'with previous_response' do
      let(:previous_response) { 'This is the previous responses result' }

      it 'includes previous result in prompt' do
        expect(template.to_prompt[:messages][0][:content]).to include(
          <<~CONTENT
          <previous_response>
          This is the previous responses result
          </previous_response>
          CONTENT
        )
      end
    end

    context 'with source_project_id' do
      let_it_be(:source_project) { create(:project) }

      let(:params) do
        {
          source_project_id: source_project.id,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          description: 'Client merge request description',
          user_prompt: 'Hello world from user prompt',
          title: merge_request.title
        }
      end

      context 'when user can create a merge request in source project' do
        before_all do
          source_project.add_developer(user)
        end

        it 'uses project instead of source project' do
          expect(Gitlab::Llm::Utils::MergeRequestTool).to receive(:extract_diff)
            .with(
              source_project: source_project,
              source_branch: params[:source_branch],
              target_project: project,
              target_branch: params[:target_branch],
              character_limit: 10000
            )

          template.to_prompt
        end
      end

      context 'when user can not create a merge request in source project' do
        it 'uses project instead of source project' do
          expect(Gitlab::Llm::Utils::MergeRequestTool).to receive(:extract_diff)
            .with(
              source_project: project,
              source_branch: params[:source_branch],
              target_project: project,
              target_branch: params[:target_branch],
              character_limit: 10000
            )

          template.to_prompt
        end
      end
    end
  end
end
