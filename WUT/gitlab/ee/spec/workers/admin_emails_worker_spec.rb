# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AdminEmailsWorker, feature_category: :team_planning do
  context "recipients" do
    let(:group) { create(:group) }
    let(:project) { create(:project) }

    before do
      2.times do
        user = create(:user)
        group.add_member(user, Gitlab::Access::DEVELOPER)
        project.add_member(user, Gitlab::Access::DEVELOPER)
      end
      unsubscribed_user = create(:user, admin_email_unsubscribed_at: 5.days.ago)
      group.add_member(unsubscribed_user, Gitlab::Access::DEVELOPER)
      project.add_member(unsubscribed_user, Gitlab::Access::DEVELOPER)

      blocked_user = create(:user, state: :blocked)
      group.add_member(blocked_user, Gitlab::Access::DEVELOPER)
      project.add_member(blocked_user, Gitlab::Access::DEVELOPER)
      ActionMailer::Base.deliveries = []
    end

    context "sending emails to members of a group only" do
      let(:recipient_id) { "group-#{group.id}" }

      it "sends email to subscribed users" do
        perform_enqueued_jobs do
          subject.perform(recipient_id, 'subject', 'body')

          expect(ActionMailer::Base.deliveries.count).to eq(2)
        end
      end
    end

    context "sending emails to members of a project only" do
      let(:recipient_id) { "project-#{project.id}" }

      it "sends email to subscribed users" do
        perform_enqueued_jobs do
          subject.perform(recipient_id, 'subject', 'body')

          expect(ActionMailer::Base.deliveries.count).to eq(3)
        end
      end
    end

    context "sending emails to users directly" do
      let(:recipient_id) { "all" }

      it "sends email to subscribed users" do
        perform_enqueued_jobs do
          subject.perform(recipient_id, 'subject', 'body')

          expect(ActionMailer::Base.deliveries.count).to eq(3)
        end
      end
    end
  end
end
