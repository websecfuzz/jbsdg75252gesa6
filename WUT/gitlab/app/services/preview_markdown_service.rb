# frozen_string_literal: true

# Extracts any quick actions from the text, find any users or suggestions.
# If a block is provided, then it should return rendered HTML from the
# Banzai pipeline. If there is no block, then the act of finding users
# will cause the the pipeline to be invoked.
class PreviewMarkdownService < BaseContainerService
  def execute(&block)
    text, commands = explain_quick_actions(params[:text])
    @rendered_html = yield(text) if block
    users = find_user_references(text)
    suggestions = find_suggestions(text)

    success(
      text: text,
      rendered_html: @rendered_html,
      users: users,
      suggestions: suggestions,
      commands: commands.join('<br>')
    )
  end

  private

  def quick_action_types
    %w[Issue MergeRequest Commit WorkItem]
  end

  def explain_quick_actions(text)
    return text, [] unless quick_action_types.include?(target_type)

    quick_actions_service = QuickActions::InterpretService.new(container: container, current_user: current_user)
    quick_actions_service.explain(text, find_commands_target, keep_actions: params[:render_quick_actions])
  end

  def find_user_references(text)
    extractor = Gitlab::ReferenceExtractor.new(project, current_user)
    context = { author: current_user }
    context[:rendered] = @rendered_html if @rendered_html
    extractor.analyze(text, context)
    extractor.users.map(&:username)
  end

  def find_suggestions(text)
    return [] unless preview_sugestions?

    position = Gitlab::Diff::Position.new(new_path: params[:file_path],
      new_line: params[:line].to_i,
      base_sha: params[:base_sha],
      head_sha: params[:head_sha],
      start_sha: params[:start_sha])

    Gitlab::Diff::SuggestionsParser.parse(text, position: position,
      project: project,
      supports_suggestion: params[:preview_suggestions])
  end

  def preview_sugestions?
    params[:preview_suggestions] &&
      target_type == 'MergeRequest' &&
      Ability.allowed?(current_user, :download_code, project)
  end

  def find_commands_target
    QuickActions::TargetService
      .new(container: container, current_user: current_user)
      .execute(target_type, target_id)
  end

  def target_type
    params[:target_type]
  end

  def target_id
    params[:target_id]
  end
end

PreviewMarkdownService.prepend_mod
