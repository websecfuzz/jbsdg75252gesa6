# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::Internal::CategorizeChatQuestionService, :saas, feature_category: :duo_chat do
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:resource) { user }
  let_it_be(:options) { {} }
  let(:action_name) { :categorize_question }

  subject { described_class.new(user, resource, options) }

  describe '#execute' do
    context 'when the user is allowed to use Duo Chat' do
      before do
        allow(user).to receive(:allowed_to_use?).with(:duo_chat).and_return(true)
      end

      it_behaves_like 'schedules completion worker'
    end

    context 'when the user is not allowed to use Duo Chat' do
      before do
        allow(user).to receive(:allowed_to_use?).with(:duo_chat).and_return(false)
      end

      it_behaves_like 'does not schedule completion worker'
    end
  end
end
