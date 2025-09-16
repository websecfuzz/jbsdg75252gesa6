# frozen_string_literal: true

class PathLockPolicy < BasePolicy # rubocop:disable Gitlab/NamespacedClass
  delegate { @subject.project }

  condition(:is_author) { @user && @subject.user == @user }
  condition(:is_project_member) { @subject.project&.member?(@user) }

  rule { (is_author & is_project_member) | can?(:admin_path_locks) }.enable :destroy_path_lock
end
