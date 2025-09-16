# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Group, feature_category: :groups_and_projects do
  specify do
    expected_permissions = [:generate_description]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end
