# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::JoinEarlyAccessProgramService, feature_category: :user_management do
  subject(:execute) { described_class.new(user).execute }

  let(:user) { create(:user) }

  before do
    allow(::Users::ExperimentalCommunicationOptInWorker)
      .to receive(:perform_async).with(user.id)
  end

  context 'when user is not early access program participant' do
    it 'makes user a participant' do
      execute

      expect(user.user_preference.early_access_program_participant).to be(true)
    end

    it 'calls worker' do
      execute

      expect(::Users::ExperimentalCommunicationOptInWorker)
        .to have_received(:perform_async)
    end
  end

  context 'when user already participating' do
    before do
      user.user_preference.update!(early_access_program_participant: true)
    end

    it "doesn't call worker" do
      execute

      expect(::Users::ExperimentalCommunicationOptInWorker)
        .not_to have_received(:perform_async)
    end

    it "keeps user as participant" do
      execute

      expect(user.user_preference.early_access_program_participant).to be(true)
    end
  end
end
