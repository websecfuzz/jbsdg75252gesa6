# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::DuoUserFeedback, :clean_gitlab_redis_chat, feature_category: :ai_abstraction_layer do
  include GraphqlHelpers
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:agent_version) { create(:ai_agent_version) }

  subject(:mutation) { described_class.new(object: nil, context: query_context(user: user), field: nil) }

  describe '#resolve' do
    let(:chat_storage) { Gitlab::Llm::ChatStorage.new(user, agent_version.id) }
    let(:messages) { create_list(:ai_chat_message, 3, user: user, agent_version_id: agent_version.id) }
    let(:ai_message_id) { messages.first.id }
    let(:input) { { agent_version_id: agent_version.to_gid, ai_message_id: ai_message_id } }

    subject(:resolve) { mutation.resolve(**input) }

    it 'marks the message as having feedback' do
      resolve

      expect(chat_storage.messages.find { |m| m.message_xid == ai_message_id }.extras['has_feedback']).to be(true)
    end

    context 'without a user' do
      let(:mutation) { described_class.new(object: nil, context: query_context(user: nil), field: nil) }

      it 'raises a ResourceNotAvailable error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'with a non-existing message id' do
      let(:ai_message_id) { 'non-existing' }

      it 'raises a ResourceNotAvailable error' do
        expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
