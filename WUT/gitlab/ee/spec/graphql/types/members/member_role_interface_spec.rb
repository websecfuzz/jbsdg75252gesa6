# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Members::MemberRoleInterface, feature_category: :system_access do
  it 'exposes the expected fields' do
    expected_fields = %i[membersCount usersCount]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
