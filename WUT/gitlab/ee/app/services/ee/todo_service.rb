# frozen_string_literal: true

module EE
  module TodoService
    extend ::Gitlab::Utils::Override

    def duo_core_access_granted(users)
      attributes = {
        target_type: ::User.name,
        action: ::Todo::DUO_CORE_ACCESS_GRANTED,
        author_id: ::Users::Internal.duo_code_review_bot.id
      }

      eligible_users = users_who_have_not_received_notification(attributes, users)

      bulk_insert_todos_for_user_target_type(eligible_users, attributes)

      ::Users::UpdateTodoCountCacheService.new(eligible_users.map(&:id)).execute
    end

    def duo_pro_access_granted(user)
      attributes = {
        target_id: user.id,
        target_type: ::User,
        action: ::Todo::DUO_PRO_ACCESS_GRANTED,
        author_id: ::Users::Internal.duo_code_review_bot.id
      }
      create_todos(user, attributes, nil, nil)
    end

    def duo_enterprise_access_granted(user)
      attributes = {
        target_id: user.id,
        target_type: ::User,
        action: ::Todo::DUO_ENTERPRISE_ACCESS_GRANTED,
        author_id: ::Users::Internal.duo_code_review_bot.id
      }
      create_todos(user, attributes, nil, nil)
    end

    def update_epic(epic, current_user, skip_users = [])
      update_issuable(epic, current_user, skip_users)
    end

    # When a merge train is aborted for some reason, we should:
    #
    #  * create a todo for each merge request participant
    #
    def merge_train_removed(merge_request)
      merge_request.merge_participants.each do |user|
        create_merge_train_removed_todo(merge_request, user)
      end
    end

    def request_okr_checkin(work_item, assignee)
      project = work_item.project

      attributes = attributes_for_todo(project, work_item, work_item.author, ::Todo::OKR_CHECKIN_REQUESTED)

      create_todos(assignee, attributes, project.namespace, project)
    end

    def added_approver(users, merge_request)
      project = merge_request.project
      attributes = attributes_for_todo(project, merge_request, merge_request.author, ::Todo::ADDED_APPROVER)

      create_todos(users, attributes, project.namespace, project)
    end

    private

    def users_who_have_not_received_notification(attributes, users)
      finder_attributes = attributes.except(:author_id).transform_keys do |key|
        case key
        when :action then :action_id
        when :target_type then :type
        end
      end

      filtered_users = ::TodosFinder.new(users: users, **finder_attributes.merge(state: :all)).execute.distinct_user_ids

      users.reject { |user| filtered_users.include?(user.id) }
    end

    override :attributes_for_target
    def attributes_for_target(target)
      attributes = super

      if target.is_a?(Epic)
        attributes[:group_id] = target.group_id
      elsif target.is_a?(WikiPage::Meta)
        attributes[:group_id] = target.namespace_id
      end

      attributes
    end

    def create_merge_train_removed_todo(merge_request, user)
      project = merge_request.project
      attributes = attributes_for_todo(project, merge_request, user, ::Todo::MERGE_TRAIN_REMOVED)
      create_todos(user, attributes, project.namespace, project)
    end

    def bulk_insert_todos_for_user_target_type(users, attributes)
      bulk_insert_todos(users, attributes) do |user, attrs|
        attrs.merge(user_id: user.id, target_id: user.id)
      end
    end
  end
end
