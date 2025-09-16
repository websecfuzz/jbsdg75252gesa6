# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Namespaces::GroupInterface, feature_category: :groups_and_projects do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('GroupInterface')
  end

  it 'has the expected fields' do
    expected_fields = %w[id name full_name web_url avatar_url]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe ".resolve_type" do
    using RSpec::Parameterized::TableSyntax

    where(:read_group, :read_group_metadata, :resolved_type) do
      false | false | ::Types::GroupType
      true  | false | ::Types::GroupType
      false | true  | ::Types::Namespaces::GroupMinimalAccessType
      true  | true  | ::Types::GroupType
    end

    with_them do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }

      subject { described_class.resolve_type(group, { current_user: user }) }

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_group, group).and_return(read_group)
        allow(user).to receive(:can?).with(:read_group_metadata, group).and_return(read_group_metadata)
      end

      it { is_expected.to eq resolved_type }
    end
  end

  it "defines GroupMinimalAccessType as one of it's orphan types" do
    expect(described_class.orphan_types).to include(::Types::Namespaces::GroupMinimalAccessType)
  end
end
