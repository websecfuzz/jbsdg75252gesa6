# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::Scim::Group, feature_category: :system_access do
  let(:group_link) { build(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: 'group-123') }
  let(:entity) { described_class.new(group_link) }

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).to eq(['urn:ietf:params:scim:schemas:core:2.0:Group'])
  end

  it 'contains the SCIM group uid' do
    expect(json_response[:id]).to eq(group_link.scim_group_uid)
  end

  it 'contains the display name' do
    expect(json_response[:displayName]).to eq(group_link.saml_group_name)
  end

  it 'contains an empty members array' do
    expect(json_response[:members]).to eq([])
  end

  it 'contains the resource type' do
    expect(json_response[:meta][:resourceType]).to eq('Group')
  end

  context 'when members are excluded' do
    subject(:json_response) { described_class.new(group_link, excluded_attributes: ['members']).as_json }

    it 'does not include members in the response' do
      expect(json_response).not_to include(:members)
    end
  end
end
