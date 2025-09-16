# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CodebaseSearch
          class Executor < Tool # rubocop: disable Search/NamespacedClass -- this is a Duo Chat tool
            include ::Gitlab::Llm::Concerns::Logger

            NAME = 'CodebaseSearch'
            DESCRIPTION = 'Performs a semantic search on the codebase'
            EXAMPLE = 'Codebase Search Tool example'

            ACTIVE_CONTEXT_QUERY_CLASS = ::Ai::ActiveContext::Queries::Code

            PROJECT_GLOBAL_ID_PATTERN = %r{gid://gitlab/Project/(\d+)}

            def perform
              return no_repository_contexts_answer unless has_codebase_context?

              log_semantic_search_requesting

              enhance_codebase_context

              log_semantic_search_requested

              successful_answer
            rescue StandardError => e
              error_message = "Error in semantic search: #{e.class} #{e.message}"

              log_event_error(error_message)

              Answer.new(status: :error, context: context, content: error_message, tool: nil)
            end

            def authorize
              Utils::ChatAuthorizer.user(user: context.current_user).allowed?
            end

            def unit_primitive
              'codebase_search'
            end

            private

            def has_codebase_context?
              project_global_ids.present?
            end

            def project_global_ids
              @project_global_ids ||= context.additional_context.filter_map do |ctx|
                case ctx[:category]
                when 'repository'
                  ctx[:id]
                when 'directory'
                  ctx.dig(:metadata, 'projectId')
                end
              end
            end

            def enhance_codebase_context
              context.additional_context.each do |ctx|
                case ctx[:category]
                when 'repository'
                  ctx[:content] += repository_info_context(ctx[:metadata])
                  ctx[:content] += search_results_context('repository', ctx[:id])
                when 'directory'
                  ctx[:content] += directory_info_context(ctx[:metadata])
                  ctx[:content] += search_results_context(
                    'directory',
                    ctx.dig(:metadata, 'projectId'),
                    ctx.dig(:metadata, 'relativePath')
                  )
                end
              end
            end

            def repository_info_context(metadata)
              return "" if metadata.blank?

              info_contexts = [
                "Name: #{metadata['name']}",
                "Path: #{metadata['pathWithNamespace']}"
              ]
              info_contexts << "Description: #{metadata['description']}" if metadata['description']

              info_contexts.join("\n")
            end

            def directory_info_context(metadata)
              return "" if metadata.blank?

              info_contexts = [
                "Path: #{metadata['relativePath']}",
                "Repository ID: #{metadata['projectId']}"
              ]
              info_contexts << "Repository Path: #{metadata['projectPathWithNamespace']}"

              info_contexts.join("\n")
            end

            def search_results_context(category, project_global_id, path = nil)
              project_id = extract_project_id_from_global_id(project_global_id)
              return "" unless project_id

              return "" if category == 'directory' && path.blank?

              results = codebase_query.filter(project_id: project_id, path: path)

              sr_context = "\n\n" \
                "A semantic search has been performed on the #{category}. " \
                "The results are listed below enclosed in <search_result></search_result>. " \
                "Each result has a file_path and content. The content may be a snippet " \
                "within the file or the full file content.\n\n"
              sr_context += results.map do |r|
                "<search_result>\n" \
                  "<file_path>#{r['path']}</file_path>\n" \
                  "<content>#{r['content']}</content>\n" \
                  "</search_result>"
              end.join("\n\n")

              sr_context
            end

            def codebase_query
              @codebase_query ||= ACTIVE_CONTEXT_QUERY_CLASS.new(
                search_term: options[:input],
                user: context.current_user
              )
            end

            def extract_project_id_from_global_id(project_global_id)
              return if project_global_id.blank?

              match_data = PROJECT_GLOBAL_ID_PATTERN.match(project_global_id)
              return unless match_data && match_data[1]

              match_data[1].to_i
            end

            def log_semantic_search_requesting
              message = "Requesting semantic search for \"#{options[:input]}\" " \
                "on projects #{project_global_ids}"

              log_event_info(
                name: 'requesting',
                message: message
              )
            end

            def log_semantic_search_requested
              message = "Semantic search requested for \"#{options[:input]}\" " \
                "on projects #{project_global_ids}"

              log_event_info(
                name: 'requested',
                message: message
              )
            end

            def log_event_info(name:, message:)
              log_info(
                event_name: event_name(name),
                message: message,
                unit_primitive: unit_primitive,
                ai_component: 'duo_chat'
              )
            end

            def log_event_error(error_message)
              log_error(
                message: error_message,
                event_name: event_name('failed'),
                unit_primitive: unit_primitive,
                ai_component: 'duo_chat'
              )
            end

            def event_name(name)
              "#{unit_primitive}_#{name}"
            end

            def successful_answer
              message = "The repository additional contexts have been enhanced with semantic search results."
              Answer.new(status: :ok, context: context, content: message, tool: nil)
            end

            def no_repository_contexts_answer
              message = "There are no repository additional contexts. Semantic search was not executed."
              Answer.new(status: :not_executed, context: context, content: message, tool: nil)
            end
          end
        end
      end
    end
  end
end
