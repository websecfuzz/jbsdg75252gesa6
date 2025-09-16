# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::ParticipantsService, feature_category: :code_review_workflow do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    subject do
      described_class.new(project, current_user, {}).execute(merge_request)
    end

    context 'when project does not have access to Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
      end

      it { is_expected.not_to include(a_hash_including({ username: ::Users::Internal.duo_code_review_bot.username })) }
    end

    context 'when project has access Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
      end

      it { is_expected.to include(a_hash_including({ username: ::Users::Internal.duo_code_review_bot.username })) }
    end
  end
end
