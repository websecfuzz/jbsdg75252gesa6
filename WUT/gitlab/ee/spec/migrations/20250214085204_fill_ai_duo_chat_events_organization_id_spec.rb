# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe FillAiDuoChatEventsOrganizationId, feature_category: :value_stream_management do
  let(:organization) { table(:organizations).create!(path: 'org-path', id: 5) }
  let(:user) { table(:users).create!(username: 'foo_bar', email: 'foo@bar.com', projects_limit: 0) }
  let(:personal_namespace) do
    table(:namespaces).create!(
      name: 'foo_namespace',
      path: 'foo_namespace',
      organization_id: organization.id)
  end

  let(:ai_duo_chat_events) { partitioned_table(:ai_duo_chat_events) }

  let!(:event1) do
    ai_duo_chat_events.create!(
      id: 1001,
      user_id: user.id,
      personal_namespace_id: personal_namespace.id,
      organization_id: nil,
      event: 1,
      timestamp: 1.day.ago)
  end

  let!(:event2) do
    ai_duo_chat_events.create!(
      id: 1002,
      user_id: user.id,
      personal_namespace_id: personal_namespace.id,
      organization_id: organization.id,
      event: 1,
      timestamp: 2.days.ago)
  end

  it 'updates all events without organization to default one' do
    migrate!

    expect(ai_duo_chat_events.find_by(id: event1.id).organization_id)
      .to eq(Organizations::Organization::DEFAULT_ORGANIZATION_ID)
    expect(ai_duo_chat_events.find_by(id: event2.id).organization_id).to eq(organization.id)
  end

  context 'for EE' do
    before do
      allow(Gitlab).to receive(:ee?).and_return(true)
    end

    it 'does not raise an exception' do
      expect { migrate! }.not_to raise_error
    end
  end
end
