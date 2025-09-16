# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Emails::EnterpriseUsers, feature_category: :user_management do
  include EmailSpec::Matchers

  include_context 'gitlab email notification'

  describe 'user_associated_with_enterprise_group_email' do
    subject { Notify.user_associated_with_enterprise_group_email(user_id) }

    let(:user_id) { user.id }
    let(:recepient) { user }

    context 'when there is no user for given user_id' do
      let(:user) { build(:user, id: -1) }

      it_behaves_like 'no email is sent'
    end

    context 'when user is not an enterprise user' do
      let_it_be(:user) { create(:user) } # rubocop:todo RSpec/FactoryBot/AvoidCreate

      it_behaves_like 'no email is sent'
    end

    context 'when user is an enterprise user' do
      let_it_be(:user) { create(:enterprise_user) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- The user needs to be persisted to check if email was delivered

      it 'delivers mail to user email' do
        expect(subject).to deliver_to(user.email)
      end

      it_behaves_like 'an email sent from GitLab'
      it_behaves_like 'it should not have Gmail Actions links'
      it_behaves_like 'a user cannot unsubscribe through footer link'
      it_behaves_like 'appearance header and footer enabled'
      it_behaves_like 'appearance header and footer not enabled'

      it 'has the correct subject and body' do
        is_expected.to have_subject 'Enterprise User Account on GitLab'

        is_expected.to have_text_part_content(help_page_url('user/enterprise_user/_index.md'))
        is_expected.to have_html_part_content(help_page_url('user/enterprise_user/_index.md'))

        is_expected.to have_text_part_content(user.user_detail.enterprise_group.name)
        is_expected.to have_html_part_content(user.user_detail.enterprise_group.name)

        is_expected.to have_text_part_content(user.user_detail.enterprise_group.web_url)
        is_expected.to have_html_part_content(user.user_detail.enterprise_group.web_url)

        is_expected.to have_text_part_content(user.username)
        is_expected.to have_html_part_content(user.username)

        is_expected.to have_text_part_content(user.email)
        is_expected.to have_html_part_content(user.email)
      end

      context 'when enterprise user is unconfirmed' do
        let_it_be(:user) { create(:enterprise_user, :unconfirmed) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- The user needs to be persisted to check if email was delivered

        it 'delivers mail to user email' do
          expect(subject).to deliver_to(user.email)
        end

        it 'has the correct subject and body' do
          is_expected.to have_subject 'Enterprise User Account on GitLab'
        end
      end
    end
  end
end
