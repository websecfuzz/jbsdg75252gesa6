# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Emails::BlockSeatOverages, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  describe '#no_more_seats' do
    let_it_be(:recipient_email) { 'admin@email.com' }
    let_it_be(:recipient) { build(:user, id: 1, email: recipient_email, name: 'RecipientName') }
    let_it_be(:user) { build(:user, id: 2, email: 'user@email.com', name: 'UserName') }
    let_it_be(:project_or_group) { build(:group, id: 111, name: 'GroupName') }

    subject(:email) { Notify.no_more_seats(recipient.id, user.id, project_or_group) }

    context "when recipient exists" do
      let_it_be(:email_subject) { 'Action required: Purchase more seats' }

      before do
        allow(User).to receive(:find_by_id).with(1).and_return(recipient)
        allow(User).to receive(:find_by_id).with(2).and_return(user)
      end

      it 'sends the email to the correct recipient' do
        expect(email).to be_delivered_to([recipient.notification_email_or_default])
      end

      it 'sends the email with expected contents' do
        expect(email).to have_subject(email_subject)

        expect(email.html_part.to_s).to include("Hi #{recipient.name},")
        expect(email.html_part.to_s)
          .to include("#{user.name} tried to invite the following users to the " \
                      "<strong>#{project_or_group.name}</strong> group, but your namespace has no available seats.")
        expect(email.html_part.to_s).to include("You must purchase more seats for your subscription before these " \
                                                "users can be added.")
        expect(email.html_part.to_s).to include("Purchasing more seats does not automatically approve " \
                                                "<strong>requested</strong> users.")
        expect(email.html_part.to_s).to include("After you complete your purchase, you should ask #{user.name} to " \
                                                "make another request to add these users.")
      end

      it 'shows a link to buy more seats' do
        expect(email.html_part.to_s)
          .to include(::Gitlab::Routing.url_helpers.subscription_portal_add_extra_seats_url(project_or_group.id))
      end

      context 'when adding members to a project' do
        let_it_be(:project_or_group) { build(:project, id: 111, name: 'ProjectName') }

        it 'uses the correct label' do
          expect(email.html_part.to_s)
            .to include("#{user.name} tried to invite the following users to " \
                        "the <strong>#{project_or_group.name}</strong> project")
        end
      end
    end
  end
end
