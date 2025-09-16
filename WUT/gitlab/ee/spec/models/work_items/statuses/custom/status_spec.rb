# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Status, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }

  subject(:custom_status) { build_stubbed(:work_item_custom_status) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:created_by) }
    it { is_expected.to belong_to(:updated_by) }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:lifecycles).through(:lifecycle_statuses) }
  end

  describe 'scopes' do
    describe '.in_namespace' do
      let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: group) }
      let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: group) }

      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_open_status) { create(:work_item_custom_status, :open, namespace: other_group) }

      it 'returns statuses for a specific namespace' do
        expect(described_class.in_namespace(group)).to contain_exactly(open_status, closed_status)
      end
    end

    describe '.ordered_for_lifecycle' do
      let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: group) }
      let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: group) }
      let_it_be(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: group) }
      let_it_be(:in_review_status) do
        create(:work_item_custom_status, category: :in_progress, name: 'In review', namespace: group)
      end

      let_it_be(:in_dev_status) do
        create(:work_item_custom_status, category: :in_progress, name: 'In dev', namespace: group)
      end

      let_it_be(:custom_lifecycle) do
        create(:work_item_custom_lifecycle,
          namespace: group,
          default_open_status: open_status,
          default_closed_status: closed_status,
          default_duplicate_status: duplicate_status
        )
      end

      before do
        create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_review_status, position: 2)
        create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_dev_status, position: 1)
      end

      it 'returns statuses ordered by category, position, and id for a specific lifecycle' do
        ordered_statuses = described_class.ordered_for_lifecycle(custom_lifecycle.id)

        expect(ordered_statuses.map(&:name)).to eq([
          open_status.name,
          in_dev_status.name,
          in_review_status.name,
          closed_status.name,
          duplicate_status.name
        ])

        expect(ordered_statuses.map(&:category)).to eq(%w[to_do in_progress in_progress done canceled])
      end
    end

    describe '.converted_from_system_defined' do
      let_it_be(:converted_status) do
        create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: 1)
      end

      let_it_be(:non_converted_status) do
        create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: nil)
      end

      it 'returns statuses that were converted from a system defined status' do
        expect(described_class.converted_from_system_defined).to contain_exactly(converted_status)
      end
    end
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(32) }
    it { is_expected.to validate_presence_of(:color) }
    it { is_expected.to validate_length_of(:color).is_at_most(7) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_length_of(:description).is_at_most(128).allow_blank }

    context 'with name uniqueness' do
      it 'validates uniqueness with a custom validator' do
        create(:work_item_custom_status, name: "Test Status", namespace: group)

        duplicate_status = build(:work_item_custom_status, name: " test status ", namespace: group)
        expect(duplicate_status).to be_invalid
        expect(duplicate_status.errors.full_messages).to include('Name has already been taken')

        new_status = build(:work_item_custom_status, name: "Test Status", namespace: create(:group))
        expect(new_status).to be_valid
      end
    end

    describe 'status per namespace limit validations' do
      let_it_be(:existing_status) { create(:work_item_custom_status, namespace: group) }

      before do
        stub_const('WorkItems::Statuses::Custom::Status::MAX_STATUSES_PER_NAMESPACE', 1)
      end

      it 'is invalid when exceeding maximum allowed statuses' do
        new_status = build(:work_item_custom_status, namespace: group)

        expect(new_status).not_to be_valid
        expect(new_status.errors[:namespace]).to include('can only have a maximum of 1 statuses.')
      end

      it 'allows updating attributes of an existing status when limit is reached' do
        existing_status.name = 'Updated Name'

        expect(existing_status).to be_valid
      end
    end

    context 'with invalid color' do
      it 'is invalid' do
        custom_status.color = '000000'
        expect(custom_status).to be_invalid
        expect(custom_status.errors[:color]).to include('must be a valid color code')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:category).with_values(described_class::CATEGORIES) }
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
    it { is_expected.to include(WorkItems::Statuses::Status) }
  end

  describe '.find_by_namespace_and_name' do
    let_it_be(:custom_status) { create(:work_item_custom_status, name: 'In progress', namespace: group) }

    it 'finds a custom status by namespace and name' do
      expect(described_class.find_by_namespace_and_name(group, 'In progress')).to eq(custom_status)
    end

    it 'ignores leading and trailing whitespace and matches case insensitively' do
      expect(described_class.find_by_namespace_and_name(group, ' in Progress ')).to eq(custom_status)
    end

    it 'returns nil when name does not match' do
      expect(described_class.find_by_namespace_and_name(group, 'other status')).to be_nil
    end
  end

  describe '#icon_name' do
    it 'returns the icon name based on the category' do
      expect(custom_status.icon_name).to eq('status-waiting')
    end
  end

  describe '#position' do
    it 'returns 0 as the default position' do
      expect(custom_status.position).to eq(0)
    end
  end

  describe '#in_use?' do
    let(:custom_status) { create(:work_item_custom_status, namespace: group) }

    context 'when custom status is in use' do
      let(:work_item) { create(:work_item, namespace: group) }
      let!(:current_status) do
        create(:work_item_current_status, custom_status: custom_status, work_item: work_item, namespace: group)
      end

      it 'returns true' do
        expect(custom_status.in_use?).to be_truthy
      end
    end

    context 'when custom status is not in use' do
      it 'returns false' do
        expect(custom_status.in_use?).to be_falsy
      end
    end
  end
end
