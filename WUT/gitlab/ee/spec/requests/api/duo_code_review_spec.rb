# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DuoCodeReview, feature_category: :code_review_workflow do
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:unauthorized_user) { build(:user) }

  let_it_be(:tokens) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: authorized_user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: authorized_user),
      ai_features: create(:personal_access_token, scopes: %w[ai_features], user: authorized_user)
    }
  end

  describe 'POST /duo_code_review/evaluations' do
    let(:dev_or_test_env?) { true }
    let(:license_feature_available) { true }
    let(:global_feature_flag_enabled) { true }
    let(:current_user) { authorized_user }
    let(:raw_diffs) do
      <<~DIFFS
        diff --git a/path.md b/path.md
        index 1234567..abcdefg 100644
        --- a/path.md
        +++ b/path.md
        @@ -1,1 +1,1 @@
        -Old content
        +New content
      DIFFS
    end

    let(:mr_title) { 'Test MR Title' }
    let(:mr_description) { 'Test MR Description' }
    let(:file_content) { "# Title\n\nNew content\n\nMore content" }
    let(:headers) { {} }

    let(:body) do
      {
        diffs: raw_diffs,
        mr_title: mr_title,
        mr_description: mr_description,
        file_contents: { 'path.md' => file_content }
      }
    end

    let(:review_prompt) { { messages: ['prompt'] } }
    let(:review_response) { { content: [{ text: 'Review response' }] } }
    let(:expected_diffs_and_paths) do
      {
        'path.md' => raw_diffs
      }
    end

    let(:expected_files_content) do
      {
        'path.md' => file_content
      }
    end

    subject(:post_api) do
      post api('/duo_code_review/evaluations', current_user), headers: headers, params: body
    end

    before do
      stub_licensed_features(review_merge_request: license_feature_available)
      stub_feature_flags(ai_global_switch: global_feature_flag_enabled)

      allow(Gitlab).to receive(:dev_or_test_env?).and_return(dev_or_test_env?)

      allow_next_instance_of(
        ::Gitlab::Llm::Templates::ReviewMergeRequest,
        hash_including(
          mr_title: mr_title,
          mr_description: mr_description,
          diffs_and_paths: expected_diffs_and_paths,
          files_content: expected_files_content,
          user: authorized_user
        )
      ) do |prompt|
        allow(prompt).to receive(:to_prompt).and_return(review_prompt)
      end

      allow_next_instance_of(
        ::Gitlab::Llm::Anthropic::Client,
        authorized_user,
        unit_primitive: 'review_merge_request'
      ) do |client|
        allow(client)
          .to receive(:messages_complete)
          .with(review_prompt)
          .and_return(review_response)
      end

      post_api
    end

    it 'returns 201 with the review response' do
      expect(response).to have_gitlab_http_status(:created)
      expect(response.body).to eq({ review: 'Review response' }.to_json)
    end

    it 'passes file contents to the template' do
      expect(::Gitlab::Llm::Templates::ReviewMergeRequest)
        .to have_received(:new)
        .with(hash_including(
          mr_title: mr_title,
          mr_description: mr_description,
          diffs_and_paths: expected_diffs_and_paths,
          files_content: expected_files_content,
          user: authorized_user
        ))
    end

    context 'when environment is not development or test' do
      let(:dev_or_test_env?) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it { expect(response).to have_gitlab_http_status(:unauthorized) }
    end

    context 'when feature is not available in license' do
      let(:license_feature_available) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when token is used' do
      let(:current_user) { nil }
      let(:access_token) { tokens[:api] }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

      it { expect(response).to have_gitlab_http_status(:created) }

      context 'when using token with :ai_features scope' do
        let(:access_token) { tokens[:ai_features] }

        it { expect(response).to have_gitlab_http_status(:created) }
      end

      context 'when using token with :read_api scope' do
        let(:access_token) { tokens[:read_api] }

        it { expect(response).to have_gitlab_http_status(:forbidden) }
      end
    end

    context 'when required parameters are missing' do
      context 'when mr_title parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_description: mr_description,
            file_contents: { 'path.md' => file_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when mr_description parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_title: mr_title,
            file_contents: { 'path.md' => file_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when diffs parameter is missing' do
        let(:body) do
          {
            mr_title: mr_title,
            mr_description: mr_description,
            file_contents: { 'path.md' => file_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when file_contents parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_title: mr_title,
            mr_description: mr_description
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end
    end

    context 'with more complex diff content' do
      let(:raw_diffs) do
        <<~DIFFS
        diff --git a/file1.rb b/file1.rb
        index 123..456 100644
        --- a/file1.rb
        +++ b/file1.rb
        @@ -1,3 +1,3 @@
        -old line
        +new line
        unchanged
        diff --git a/file2.rb b/file2.rb
        index 789..012 100644
        --- a/file2.rb
        +++ b/file2.rb
        @@ -5,2 +5,2 @@
        -another old line
        +another new line
        DIFFS
      end

      let(:file1_content) { "# File 1\nnew line\nunchanged\nmore content" }
      let(:file2_content) { "# File 2\nsome content\nanother new line" }
      let(:body) do
        {
          diffs: raw_diffs,
          mr_title: mr_title,
          mr_description: mr_description,
          file_contents: {
            'file1.rb' => file1_content,
            'file2.rb' => file2_content
          }
        }
      end

      let(:expected_diffs_and_paths) do
        {
          'file1.rb' => %r{diff --git a/file1\.rb b/file1\.rb.+}m,
          'file2.rb' => %r{diff --git a/file2\.rb b/file2\.rb.+}m
        }
      end

      let(:expected_files_content) do
        {
          'file1.rb' => file1_content,
          'file2.rb' => file2_content
        }
      end

      before do
        allow_next_instance_of(
          ::Gitlab::Llm::Templates::ReviewMergeRequest,
          hash_including(
            mr_title: mr_title,
            mr_description: mr_description,
            diffs_and_paths: expected_diffs_and_paths,
            files_content: expected_files_content,
            user: authorized_user
          )
        ) do |prompt|
          allow(prompt).to receive(:to_prompt).and_return(review_prompt)
        end
      end

      it 'correctly processes multiple files' do
        expect(response).to have_gitlab_http_status(:created)
        expect(::Gitlab::Llm::Templates::ReviewMergeRequest).to have_received(:new).with(
          hash_including(
            mr_title: mr_title,
            mr_description: mr_description,
            diffs_and_paths: expected_diffs_and_paths,
            files_content: expected_files_content
          )
        )
      end
    end
  end
end
