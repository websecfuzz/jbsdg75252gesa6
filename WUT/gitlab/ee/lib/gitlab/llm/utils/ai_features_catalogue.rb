# frozen_string_literal: true

module Gitlab
  module Llm
    module Utils
      class AiFeaturesCatalogue
        LIST = {
          explain_vulnerability: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :vulnerability_management,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          resolve_vulnerability: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::ResolveVulnerability,
            prompt_class: ::Gitlab::Llm::Templates::Vulnerabilities::ResolveVulnerability,
            feature_category: :vulnerability_management,
            execute_method: ::Llm::ResolveVulnerabilityService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          summarize_comments: {
            service_class: ::Gitlab::Llm::Completions::SummarizeAllOpenNotes,
            prompt_class: nil,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::GenerateSummaryService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          summarize_review: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::SummarizeReview,
            prompt_class: ::Gitlab::Llm::Templates::SummarizeReview,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::MergeRequests::SummarizeReviewService,
            maturity: :experimental,
            self_managed: true,
            internal: false
          },
          measure_comment_temperature: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::MeasureCommentTemperature,
            prompt_class: nil,
            feature_category: :ai_abstraction_layer,
            execute_method: ::Llm::Notes::MeasureCommentTemperatureService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          generate_description: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::GenerateDescription,
            prompt_class: ::Gitlab::Llm::Templates::GenerateDescription,
            feature_category: :team_planning,
            execute_method: ::Llm::GenerateDescriptionService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          generate_commit_message: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::GenerateCommitMessage,
            prompt_class: ::Gitlab::Llm::Templates::GenerateCommitMessage,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::GenerateCommitMessageService,
            maturity: :ga,
            self_managed: true,
            internal: false
          },
          description_composer: {
            service_class: ::Gitlab::Llm::Anthropic::Completions::DescriptionComposer,
            aigw_service_class: nil,
            prompt_class: ::Gitlab::Llm::Anthropic::Templates::DescriptionComposer,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::DescriptionComposerService,
            maturity: :experimental,
            self_managed: true,
            internal: false
          },
          chat: {
            service_class: ::Gitlab::Llm::Completions::Chat,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: ::Llm::ChatService,
            maturity: :ga,
            self_managed: true,
            internal: false,
            alternate_name: :duo_chat
          },
          summarize_new_merge_request: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::SummarizeNewMergeRequest,
            prompt_class: ::Gitlab::Llm::Templates::SummarizeNewMergeRequest,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::SummarizeNewMergeRequestService,
            maturity: :beta,
            self_managed: true,
            internal: false
          },
          generate_cube_query: {
            service_class: ::Gitlab::Llm::VertexAi::Completions::GenerateCubeQuery,
            prompt_class: ::Gitlab::Llm::VertexAi::Templates::GenerateCubeQuery,
            feature_category: :product_analytics,
            execute_method: ::Llm::ProductAnalytics::GenerateCubeQueryService,
            maturity: :experimental,
            self_managed: false,
            internal: false
          },
          categorize_question: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::CategorizeQuestion,
            prompt_class: ::Gitlab::Llm::Templates::CategorizeQuestion,
            feature_category: :duo_chat,
            execute_method: ::Llm::Internal::CategorizeChatQuestionService,
            maturity: :ga,
            self_managed: false,
            internal: true
          },
          review_merge_request: {
            service_class: ::Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest,
            prompt_class: ::Gitlab::Llm::Templates::ReviewMergeRequest,
            feature_category: :code_review_workflow,
            execute_method: ::Llm::ReviewMergeRequestService,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          glab_ask_git_command: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :source_code_management,
            execute_method: ::Llm::GitCommandService,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          code_suggestions: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :continuous_integration,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          troubleshoot_job: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :code_suggestions,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          duo_workflow: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_workflow,
            execute_method: nil,
            maturity: :beta,
            self_managed: true,
            internal: true
          },
          duo_agent_platform: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_workflow,
            execute_method: nil,
            maturity: :beta,
            self_managed: true,
            internal: true
          },
          agentic_chat: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :experimental,
            self_managed: true,
            internal: false
          },
          # The proxies are not features per-se, but an entry in the catalogue is required when building the AI
          # Gateway headers. See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/168117#note_2142272386
          anthropic_proxy: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :ai_abstraction_layer,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          vertex_ai_proxy: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :ai_abstraction_layer,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          ask_build: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          ask_issue: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          ask_epic: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          ask_merge_request: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          },
          ask_commit: {
            service_class: nil,
            prompt_class: nil,
            feature_category: :duo_chat,
            execute_method: nil,
            maturity: :ga,
            self_managed: true,
            internal: true
          }
        }.freeze

        def self.external
          LIST.select { |_, v| v[:internal] == false }
        end

        def self.with_service_class
          LIST.select { |_, v| v[:service_class].present? }
        end

        def self.for_saas
          LIST.select { |_, v| v[:self_managed] == false }
        end

        def self.for_sm
          LIST.select { |_, v| v[:self_managed] == true }
        end

        def self.ga
          LIST.select { |_, v| v[:maturity] == :ga }
        end

        def self.search_by_name(name)
          return unless name
          return LIST[name] if LIST.key?(name)

          LIST.select { |_, v| v[:alternate_name] == name }.values.first
        end
      end
    end
  end
end
