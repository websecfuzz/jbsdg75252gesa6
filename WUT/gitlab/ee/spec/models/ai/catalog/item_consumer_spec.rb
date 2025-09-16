# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumer, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:item).required }

    it { is_expected.to belong_to(:organization).optional }
    it { is_expected.to belong_to(:group).optional }
    it { is_expected.to belong_to(:project).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:locked).in_array([true, false]) }

    it { is_expected.to validate_length_of(:pinned_version_prefix).is_at_most(50) }

    describe '#validate_exactly_one_sharding_key_present' do
      let(:organization_stub) { build_stubbed(:organization) }
      let(:group_stub) { build_stubbed(:group) }
      let(:project_stub) { build_stubbed(:project) }

      where(:case_name, :organization, :group, :project, :expected_validity) do
        [
          ['only organization', ref(:organization_stub), nil, nil, true],
          ['only group', nil, ref(:group_stub), nil, true],
          ['only project', nil, nil, ref(:project_stub), true],
          ['organization and group', ref(:organization_stub), ref(:group_stub), nil, false],
          ['organization and project', ref(:organization_stub), nil, ref(:project_stub), false],
          ['group and project', nil, ref(:group_stub), ref(:project_stub), false],
          ['all three', ref(:organization_stub), ref(:group_stub), ref(:project_stub), false],
          ['none', nil, nil, nil, false]
        ]
      end

      with_them do
        it "validates correctly for #{params[:case_name]}" do
          setting = build(:ai_catalog_item_consumer,
            item: build_stubbed(:ai_catalog_item),
            organization: organization,
            group: group,
            project: project
          )

          expect(setting.valid?).to eq(expected_validity)

          if expected_validity
            expect(setting.errors[:base]).to be_empty
          else
            expect(setting.errors[:base]).to include(
              'The item must belong to only one organization, group, or project'
            )
          end
        end
      end
    end
  end
end
