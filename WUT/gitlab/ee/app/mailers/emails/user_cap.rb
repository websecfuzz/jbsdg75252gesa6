# frozen_string_literal: true

module Emails
  module UserCap
    def user_cap_reached(user_id)
      user = User.find(user_id)
      email = user.notification_email_or_default

      @url_to_user_cap = 'https://docs.gitlab.com/ee/administration/settings/sign_up_restrictions.html#user-cap'
      @url_to_pending_users = 'https://docs.gitlab.com/ee/administration/moderate_users.html#view-user-sign-ups-pending-approval'
      @url_to_manage_pending_users = 'https://docs.gitlab.com/ee/administration/moderate_users.html#approve-or-reject-a-user-sign-up'
      @url_to_adjust_user_cap = 'https://docs.gitlab.com/ee/administration/settings/sign_up_restrictions.html#set-the-user-cap-number'
      @url_to_docs = 'https://docs.gitlab.com/'
      @url_to_support = 'https://about.gitlab.com/support/'

      email_with_layout to: email, subject: s_('AdminUsers|Important information about usage on your GitLab instance')
    end
  end
end
