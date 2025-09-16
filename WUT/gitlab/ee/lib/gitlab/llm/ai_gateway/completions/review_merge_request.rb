# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class ReviewMergeRequest < Base
          extend ::Gitlab::Utils::Override
          include Gitlab::Utils::StrongMemoize
          include Gitlab::InternalEventsTracking

          DRAFT_NOTES_COUNT_LIMIT = 50
          LINE_MATCH_THRESHOLD = 3
          UNIT_PRIMITIVE = 'review_merge_request'
          CUSTOM_INSTRUCTIONS_FILE_PATH = '.gitlab/duo/mr-review-instructions.yaml'
          COMMENT_METRICS = %i[
            total_comments
            comments_with_valid_path
            comments_with_valid_line
            comments_with_custom_instructions
            comments_line_matched_by_content
            created_draft_notes
          ].freeze

          class << self
            def resource_not_found_msg
              s_("DuoCodeReview|Can't access the merge request. When SAML single sign-on is enabled " \
                "on a group or its parent, Duo Code Reviews can't be requested from the API. Request a " \
                "review from the GitLab UI instead.")
            end

            def nothing_to_review_msg
              s_("DuoCodeReview|:wave: There's nothing for me to review.")
            end

            def no_comment_msg
              s_("DuoCodeReview|I finished my review and found nothing to comment on. Nice work! :tada:")
            end

            def error_msg
              s_("DuoCodeReview|I have encountered some problems while I was reviewing. Please try again later.")
            end
          end

          def execute
            # Progress note may not exist for existing jobs so we create one if we can
            @progress_note = find_progress_note || create_progress_note

            unless progress_note.present?
              Gitlab::ErrorTracking.track_exception(
                StandardError.new("Unable to perform Duo Code Review: progress_note and resource not found"),
                unit_primitive: UNIT_PRIMITIVE
              )
              return # Cannot proceed without both progress note and resource
            end

            # Resource can be empty when permission check fails in Llm::Internal::CompletionService.
            # This would most likely happen when the parent group has SAML SSO enabled and the Duo Code Review is
            #   triggered via an API call. It's a known limitation of SAML SSO currently.
            return update_progress_note(self.class.resource_not_found_msg) unless resource.present?

            update_review_state('review_started')

            if merge_request.ai_reviewable_diff_files.blank?
              log_duo_code_review_internal_event('find_nothing_to_review_duo_code_review_on_mr')

              update_progress_note(self.class.nothing_to_review_msg)
            else
              perform_review
            end

          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error, unit_primitive: UNIT_PRIMITIVE)

            log_duo_code_review_internal_event('encounter_duo_code_review_error_during_review')

            update_progress_note(self.class.error_msg, with_todo: true) if progress_note.present?

          ensure
            update_review_state('reviewed') if merge_request.present?

            @progress_note&.destroy
          end

          override :inputs
          def inputs
            @prompt_inputs
          end

          # required for model switching
          override :root_namespace
          def root_namespace
            merge_request.target_project.root_ancestor
          end

          private

          attr_reader :progress_note

          override :prompt_version
          def prompt_version
            # For specific customers, we want to use Claude 3.5 Sonnet for Duo Code Reviews
            # It uses the `use_claude_code_completion` feature flag because
            # it is tied to the usage of Claude models for AI features, so it is apt to use it here
            # as well. This check can be removed once we have enabled model switching.
            if Feature.enabled?(:use_claude_code_completion, root_namespace)
              '0.9.0' # Claude 3.5 Sonnet
            elsif duo_code_review_custom_instructions_enabled?
              '1.2.0' # Claude 4.0 Sonnet with custom instructions
            elsif Feature.enabled?(:duo_code_review_claude_4_0_rollout, user)
              '1.1.0' # Claude 4.0 Sonnet
            else
              '1.0.0' # Claude 3.7 Sonnet
            end
          end

          def user
            prompt_message.user
          end

          def perform_review
            # Initialize ivar that will be populated as AI review diff hunks
            @draft_notes = []
            @comment_metrics = COMMENT_METRICS.index_with(0)

            diff_files = merge_request.ai_reviewable_diff_files

            if diff_files.blank?
              log_duo_code_review_internal_event('find_nothing_to_review_duo_code_review_on_mr')

              update_progress_note(self.class.nothing_to_review_msg)

              return
            end

            mr_diff_refs = merge_request.diff_refs

            process_files(diff_files, mr_diff_refs)

            if @draft_notes.empty?
              update_progress_note(review_summary, with_todo: true)

              log_duo_code_review_internal_event('find_no_issues_duo_code_review_after_review')
            else
              publish_draft_notes
            end

            log_comment_metrics
          end

          def process_files(diff_files, mr_diff_refs)
            diffs_and_paths = {}
            files_content = {}

            diff_files.each do |diff_file|
              diffs_and_paths[diff_file.new_path] = diff_file.raw_diff
              # Skip newly added files and deleted files since their full content is already in the diff
              next if diff_file.new_file? || diff_file.deleted_file?

              content = diff_file.old_blob&.data
              files_content[diff_file.new_path] = content if content.present?
            end

            response = process_review_with_retry(diffs_and_paths, files_content)
            if note_not_required?(response)
              log_duo_code_review_internal_event('encounter_duo_code_review_error_during_review')
              return
            end

            parsed_body = ResponseBodyParser.new(response.response_body)
            comments = parsed_body.comments
            @review_description = parsed_body.review_description

            @comment_metrics[:total_comments] = comments.count

            comments_by_file = comments.group_by(&:file)
            diff_files.each do |diff_file|
              file_comments = comments_by_file[diff_file.new_path]
              next if file_comments.blank?

              @comment_metrics[:comments_with_valid_path] += file_comments.count

              process_comments(file_comments, diff_file, mr_diff_refs)
            end
          end

          def process_review_with_retry(diffs_and_paths, files_content)
            # First try with file content (if any)
            if files_content.present?
              prepare_prompt_inputs(diffs_and_paths, files_content)

              response = review_response_for_prompt_inputs
              return response unless response.errors.any?

              if duo_code_review_logging_enabled?
                Gitlab::AppLogger.info(
                  message: "Review request failed with files content, retrying without file content",
                  event: "review_merge_request_retry_without_content",
                  unit_primitive: UNIT_PRIMITIVE,
                  merge_request_id: merge_request&.id,
                  error: response.errors
                )
              end
            end

            # Retry without file content on failure or if no file content was provided
            prepare_prompt_inputs(diffs_and_paths, {})
            review_response_for_prompt_inputs
          end

          def duo_code_review_logging_enabled?
            Feature.enabled?(:duo_code_review_response_logging, user)
          end
          strong_memoize_attr :duo_code_review_logging_enabled?

          def duo_code_review_custom_instructions_enabled?
            Feature.enabled?(:duo_code_review_custom_instructions, user)
          end
          strong_memoize_attr :duo_code_review_custom_instructions_enabled?

          def process_comments(comments, diff_file, diff_refs)
            comments.each do |comment|
              diff_line = match_comment_to_diff_line(comment, diff_file.diff_lines)

              next unless diff_line.present?

              @comment_metrics[:comments_with_valid_line] += 1

              if comment.content.match?(/^According to custom instructions in .+?:/)
                @comment_metrics[:comments_with_custom_instructions] += 1
              end

              draft_note_params = build_draft_note_params(comment.content, diff_file, diff_line, diff_refs)
              next unless draft_note_params.present?

              @draft_notes << draft_note_params
            end
          end

          def match_comment_to_diff_line(comment, diff_lines)
            diff_line = find_line_by_line_numbers(comment, diff_lines)
            from_lines = comment.from&.lines(chomp: true)

            # We only want to match if we have enough context
            if from_lines.present? && from_lines.count >= LINE_MATCH_THRESHOLD
              # We can skip the full search if the diff_line already matches the first context line
              return diff_line if diff_line&.text(prefix: false) == from_lines.first

              return find_line_by_content(from_lines, diff_lines) || diff_line
            end

            diff_line
          end

          def find_line_by_content(from_lines, diff_lines)
            # We need to ignore removed lines as the match needs to be consecutive lines.
            # Also, removed line cannot have code suggestions so we don't want to match it to removed lines.
            actual_diff_lines = diff_lines.reject(&:removed?)
            found_line = nil

            # We look for the matching lines by iterating through diff_lines and comparing entire sequences of lines
            # from <from> lines.
            actual_diff_lines.each_with_index do |start_line, start_index|
              # If we don't have enough lines left to match, we should skip the rest of the lines and exit early.
              break if start_index + from_lines.count > actual_diff_lines.count
              next unless start_line.text(prefix: false) == from_lines.first

              # Try to match the entire sequence
              sequence_matches = true

              from_lines.each_with_index do |from_line, from_index|
                actual_line = actual_diff_lines[start_index + from_index]

                # If any line doesn't match, the sequence fails
                unless actual_line.text(prefix: false) == from_line
                  sequence_matches = false
                  break
                end
              end

              next unless sequence_matches

              # If we found a matching sequence
              @comment_metrics[:comments_line_matched_by_content] += 1
              found_line = start_line
              break
            end

            # Return the found line or nil if no match
            found_line
          end

          def find_line_by_line_numbers(comment, diff_lines)
            # NOTE: LLM may return invalid line numbers sometimes so we should double check the existence of the line.
            #   Also, LLM sometimes sets old_line to the same value as new_line when it should be empty
            #   for some unknown reason. We should fallback to new_line to find a match as much as possible.

            # First try to match both old_line and new_line for precision
            exact_match = diff_lines.find do |line|
              line.old_line == comment.old_line && line.new_line == comment.new_line
            end

            return exact_match if exact_match

            # Fall back to matching only new_line
            diff_lines.find { |line| comment.new_line.present? && line.new_line == comment.new_line }
          end

          def tracking_context
            {
              request_id: prompt_message.request_id,
              action: prompt_message.ai_action
            }
          end

          def review_bot
            Users::Internal.duo_code_review_bot
          end
          strong_memoize_attr :review_bot

          def merge_request
            # Fallback is needed to handle review state change as much as possible
            resource || progress_note&.noteable
          end

          def prepare_prompt_inputs(diffs_and_paths, files_content)
            @prompt_inputs = ai_prompt_class.new(
              mr_title: merge_request.title,
              mr_description: merge_request.description,
              diffs_and_paths: diffs_and_paths,
              files_content: files_content,
              custom_instructions: load_custom_instructions(diffs_and_paths.keys),
              user: user
            ).to_prompt_inputs
          end

          def load_custom_instructions(file_paths)
            return [] unless duo_code_review_custom_instructions_enabled?

            all_instructions = load_project_custom_instructions
            return [] if all_instructions.blank?

            # Select instructions whose glob patterns match any of the diff files
            matching_instructions = all_instructions.select do |instruction|
              file_paths.any? { |path| matches_pattern?(path, instruction) }
            end

            if duo_code_review_logging_enabled?
              Gitlab::AppLogger.info(
                message: "Custom instructions applied for Duo Code Review",
                event: "duo_code_review_custom_instructions_applied",
                unit_primitive: UNIT_PRIMITIVE,
                merge_request_id: merge_request&.id,
                matching_instructions_count: matching_instructions.count
              )
            end

            matching_instructions
          end

          def load_project_custom_instructions
            blob = merge_request.project.repository.blob_at(
              merge_request.target_branch_sha,
              CUSTOM_INSTRUCTIONS_FILE_PATH
            )

            return [] unless blob

            yaml_content = YAML.safe_load(blob.data)
            return [] unless yaml_content&.dig('instructions')

            yaml_content['instructions'].map do |group|
              excludes, includes = Array(group['fileFilters']).partition { |p| p.start_with?('!') }

              {
                name: group['name'],
                instructions: group['instructions'],
                include_patterns: includes,
                exclude_patterns: excludes.map { |p| p.delete_prefix('!') }
              }.with_indifferent_access
            end
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e,
              project_id: merge_request.project.id,
              merge_request_id: merge_request.id
            )
            []
          end

          def matches_pattern?(path, instruction)
            includes = instruction[:include_patterns]
            excludes = instruction[:exclude_patterns]

            # Matching logic:
            # - With include patterns: Match ONLY files that match include patterns (minus exclusions)
            # - Without include patterns: Match ALL files (minus exclusions)
            matches_include = includes.empty? || includes.any? { |pattern| File.fnmatch?(pattern, path) }
            matches_exclude = excludes.any? { |pattern| File.fnmatch?(pattern, path) }

            matches_include && !matches_exclude
          end

          def review_response_for_prompt_inputs
            response = request!
            response_modifier = self.class::RESPONSE_MODIFIER.new(post_process(response))

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, resource, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          def summary_response_for(draft_notes)
            action_name = :summarize_review
            message_attributes = {
              request_id: SecureRandom.uuid,
              content: action_name.to_s.humanize,
              role: ::Gitlab::Llm::AiMessage::ROLE_USER,
              ai_action: action_name,
              user: user,
              context: ::Gitlab::Llm::AiMessageContext.new(resource: resource)
            }
            summary_prompt_message = ::Gitlab::Llm::AiMessage.for(action: action_name).new(message_attributes)
            summarize_review = Gitlab::Llm::AiGateway::Completions::SummarizeReview.new(
              summary_prompt_message,
              nil,
              { draft_notes: draft_notes }
            )

            summarize_review.execute
          end

          def log_comment_metrics
            return unless duo_code_review_logging_enabled?

            Gitlab::AppLogger.info(
              { message: "LLM response comments metrics",
                event: "review_merge_request_llm_response_comments",
                unit_primitive: UNIT_PRIMITIVE,
                merge_request_id: merge_request&.id }.merge(@comment_metrics)
            )
          end

          def note_not_required?(response_modifier)
            response_modifier.errors.any? || response_modifier.response_body.blank?
          end

          def build_draft_note_params(comment, diff_file, line, diff_refs)
            position = {
              base_sha: diff_refs.base_sha,
              start_sha: diff_refs.start_sha,
              head_sha: diff_refs.head_sha,
              old_path: diff_file.old_path,
              new_path: diff_file.new_path,
              position_type: 'text',
              old_line: line.old_line,
              new_line: line.new_line,
              ignore_whitespace_change: false
            }

            return if review_note_already_exists?(position)

            {
              merge_request: merge_request,
              author: review_bot,
              note: comment,
              position: position
            }
          end

          def review_note_already_exists?(position)
            merge_request
              .notes
              .diff_notes
              .authored_by(review_bot)
              .positions
              .any? { |pos| pos.to_h >= position }
          end

          def create_progress_note
            return unless merge_request.present?

            ::SystemNotes::MergeRequestsService.new(
              noteable: merge_request,
              container: merge_request.project,
              author: review_bot
            ).duo_code_review_started
          end

          def update_progress_note(note, with_todo: false)
            todo_service.new_review(merge_request, review_bot) if with_todo

            ::Notes::CreateService.new(
              merge_request.project,
              review_bot,
              noteable: merge_request,
              note: note
            ).execute
          end

          def find_progress_note
            Note.find_by_id(options[:progress_note_id])
          end

          def summary_note(draft_notes)
            response = summary_response_for(draft_notes)
            ai_message = response[:ai_message]

            if ai_message.blank? || ai_message.errors.any? || ai_message.content.blank?
              log_duo_code_review_internal_event('encounter_duo_code_review_error_during_review')

              self.class.error_msg
            else
              ai_message.content
            end
          end

          # rubocop: disable CodeReuse/ActiveRecord -- NOT a ActiveRecord object
          def trimmed_draft_note_params
            @draft_notes.take(DRAFT_NOTES_COUNT_LIMIT)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def review_summary
            [self.class.no_comment_msg, @review_description].compact.join("\n\n")
          end

          def publish_draft_notes
            return unless Ability.allowed?(user, :create_note, merge_request)

            draft_notes = trimmed_draft_note_params.map do |params|
              DraftNote.new(params)
            end

            if draft_notes.empty?
              update_progress_note(review_summary, with_todo: true)

              log_duo_code_review_internal_event('find_no_issues_duo_code_review_after_review')

              return
            end

            DraftNote.bulk_insert_and_keep_commits!(draft_notes, batch_size: 20)

            @comment_metrics[:created_draft_notes] = draft_notes.count

            update_progress_note(summary_note(draft_notes))

            log_duo_code_review_internal_event(
              'post_comment_duo_code_review_on_diff',
              additional_properties: { value: draft_notes.size }
            )

            # We set `executing_user` as the user who executed the duo code
            # review action as we only want to publish duo code review bot's review
            # if the executing user is allowed to create notes on the MR.
            DraftNotes::PublishService
              .new(
                merge_request,
                review_bot
              ).execute(executing_user: user)
          end

          def update_review_state_service
            ::MergeRequests::UpdateReviewerStateService
              .new(project: merge_request.project, current_user: review_bot)
          end
          strong_memoize_attr :update_review_state_service

          def update_review_state(state)
            update_review_state_service.execute(merge_request, state)
          end

          def log_duo_code_review_internal_event(event_name, **additional_properties)
            track_internal_event(
              event_name,
              user: user,
              project: merge_request.project,
              **additional_properties
            )
          end

          def todo_service
            TodoService.new
          end
          strong_memoize_attr :todo_service
        end
      end
    end
  end
end
