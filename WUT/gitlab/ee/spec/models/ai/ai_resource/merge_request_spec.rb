# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::MergeRequest, feature_category: :duo_chat do
  let(:merge_request) { build(:merge_request) }
  let(:user) { build(:user) }

  subject(:wrapped_merge_request) { described_class.new(user, merge_request) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(MergeRequestSerializer).to receive_message_chain(:new, :represent)
                                  .with(current_user: user)
                                  .with(merge_request, {
                                    user: user,
                                    notes_limit: 100,
                                    serializer: 'ai',
                                    resource: wrapped_merge_request
                                  })

      wrapped_merge_request.serialize_for_ai(content_limit: 100)
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_merge_request.current_page_type).to eq('merge_request')
    end
  end
end
