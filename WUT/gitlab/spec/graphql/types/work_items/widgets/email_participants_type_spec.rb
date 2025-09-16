# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::EmailParticipantsType, feature_category: :service_desk do
  it 'exposes the expected fields' do
    expected_fields = %i[type email_participants]

    expected_fields.each do |field|
      expect(described_class).to have_graphql_field(field)
    end
  end
end
