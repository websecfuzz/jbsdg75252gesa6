# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Projects::ProjectMinimalAccessType, feature_category: :groups_and_projects do
  include GraphqlHelpers

  let(:type) { described_class }

  it 'has the correct name' do
    expect(type.graphql_name).to eq('ProjectMinimalAccess')
  end

  specify { expect(type).to require_graphql_authorizations(:read_project_metadata) }

  it 'implements the Types::Projects::ProjectInterface' do
    expect(type.interfaces).to include(Types::Projects::ProjectInterface)
  end

  describe 'fields', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
    let_it_be(:current_user) { role.user }
    let_it_be(:project) { create(:project, :private, :with_avatar, description: 'the good project') }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'only the defined fields resolve to non-nil values' do
      defined_fields = %w[name name_with_namespace description avatar_url full_path]

      expect(described_class.own_fields.keys.map(&:underscore)).to match_array(defined_fields)

      defined_fields.each do |field|
        field_value = resolve_field(field, project, current_user: current_user)
        expect(field_value).not_to be_nil
      end
    end

    describe 'inherited fields' do
      where(:field) do
        (described_class.fields.keys - described_class.own_fields.keys).map(&:underscore)
      end

      with_them do
        it 'resolves to nil' do
          expect(resolve_field(field, project, current_user: current_user)).to be_nil
        end
      end
    end
  end
end
