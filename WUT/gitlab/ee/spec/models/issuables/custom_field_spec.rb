# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomField, feature_category: :team_planning do
  subject(:custom_field) { build(:custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:created_by) }
    it { is_expected.to belong_to(:updated_by) }
    it { is_expected.to have_many(:select_options) }
    it { is_expected.to have_many(:work_item_type_custom_fields) }
    it { is_expected.to have_many(:work_item_types) }

    it 'orders select_options by position' do
      custom_field.save!

      option_1 = create(:custom_field_select_option, custom_field: custom_field, position: 2)
      option_2 = create(:custom_field_select_option, custom_field: custom_field, position: 1)

      expect(custom_field.reload.select_options).to eq([option_2, option_1])
    end

    it 'orders work_item_types by name' do
      custom_field.save!

      issue_type = create(:work_item_type, :issue)
      incident_type = create(:work_item_type, :incident)
      task_type = create(:work_item_type, :task)

      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: incident_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

      expect(custom_field.work_item_types).to eq([incident_type, issue_type, task_type])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id).case_insensitive }

    describe 'max select options' do
      let(:limit) { described_class::MAX_SELECT_OPTIONS }

      it 'is valid when select options are at the limit' do
        limit.times { custom_field.select_options.build(value: SecureRandom.hex) }

        expect(custom_field).to be_valid
      end

      it 'is not valid when select options exceed the limit' do
        (limit + 1).times { custom_field.select_options.build(value: SecureRandom.hex) }

        expect(custom_field).not_to be_valid
        expect(custom_field.errors[:select_options]).to include("exceeds the limit of #{limit}.")
      end
    end

    describe '#namespace_is_root_group' do
      subject(:custom_field) { build(:custom_field, namespace: namespace) }

      context 'when namespace is a root group' do
        let(:namespace) { build(:group) }

        it { is_expected.to be_valid }
      end

      context 'when namespace is a subgroup' do
        let(:namespace) { build(:group, parent: build(:group)) }

        it 'returns a validation error' do
          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:namespace]).to include('must be a root group.')
        end
      end

      context 'when namespace is a personal namespace' do
        let(:namespace) { build(:namespace) }

        it 'returns a validation error' do
          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:namespace]).to include('must be a root group.')
        end
      end
    end

    describe '#number_of_fields_per_namespace' do
      let_it_be(:group) { create(:group) }

      before_all do
        create(:custom_field, namespace: group)
      end

      before do
        stub_const("#{described_class}::MAX_FIELDS", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group) }

      it { is_expected.to be_valid }

      context 'when group is over the limit' do
        before_all do
          create(:custom_field, namespace: group)
        end

        shared_examples 'an invalid record' do
          it 'returns a validation error' do
            expect(custom_field).not_to be_valid
            expect(custom_field.errors[:namespace]).to include('can only have a maximum of 2 custom fields.')
          end
        end

        it_behaves_like 'an invalid record'

        context 'when creating an archived field' do
          subject(:custom_field) { build(:custom_field, :archived, namespace: group) }

          it_behaves_like 'an invalid record'
        end
      end
    end

    describe '#number_of_active_fields_per_namespace' do
      let_it_be(:group) { create(:group) }

      before do
        stub_const("#{described_class}::MAX_ACTIVE_FIELDS", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group) }

      context 'when group is not at the limit' do
        before_all do
          create(:custom_field, namespace: group)
          create(:custom_field, :archived, namespace: group)
        end

        it { is_expected.to be_valid }
      end

      context 'when group is over the limit' do
        before_all do
          create_list(:custom_field, 2, namespace: group)
          create(:custom_field, :archived, namespace: group)
        end

        it 'is valid for an archived field' do
          custom_field.archived_at = Time.current

          expect(custom_field).to be_valid
        end

        it 'is valid for an existing active field' do
          existing_field = described_class.active.first

          expect(existing_field).to be_valid
        end

        shared_examples 'an invalid record' do
          it 'returns a validation error' do
            expect(custom_field).not_to be_valid
            expect(custom_field.errors[:namespace]).to include('can only have a maximum of 2 active custom fields.')
          end
        end

        context 'with a new active field' do
          it_behaves_like 'an invalid record'
        end

        context 'when making an existing archived field active' do
          subject(:custom_field) { described_class.archived.first }

          before do
            custom_field.archived_at = nil
          end

          it_behaves_like 'an invalid record'
        end
      end
    end

    describe '#number_of_active_fields_per_namespace_per_type' do
      let_it_be(:group) { create(:group) }
      let_it_be(:issue_type) { create(:work_item_type, :issue) }
      let_it_be(:task_type) { create(:work_item_type, :task) }

      before_all do
        # Issue type under the limit
        create(:custom_field, namespace: group, work_item_types: [issue_type])

        # Custom field with issue type but from a different namespace
        create(:custom_field, namespace: create(:group), work_item_types: [issue_type])

        # Task type at the limit
        create_list(:custom_field, 2, namespace: group, work_item_types: [task_type])
      end

      before do
        stub_const("#{described_class}::MAX_ACTIVE_FIELDS_PER_TYPE", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group, work_item_types: [issue_type]) }

      it 'is valid when below the limit' do
        expect(custom_field).to be_valid
      end

      it 'is not valid when type is already at the limit' do
        custom_field.work_item_types = [task_type]

        expect(custom_field).not_to be_valid
        expect(custom_field.errors[:base]).to include(
          "Work item type #{task_type.name} can only have a maximum of 2 active custom fields."
        )
      end

      it 'is valid when field is inactive' do
        custom_field.work_item_types = [task_type]
        custom_field.archived_at = Time.current

        expect(custom_field).to be_valid
      end

      context 'when updating an existing record' do
        it 'is not valid when adding a type that is already at the limit' do
          custom_field.save!

          custom_field.work_item_types = [issue_type, task_type]

          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:base]).to include(
            "Work item type #{task_type.name} can only have a maximum of 2 active custom fields."
          )
        end
      end
    end

    describe '#selectable_field_type_with_select_options' do
      context 'when a select option exists' do
        before do
          custom_field.select_options.build(value: SecureRandom.hex)
        end

        it 'is valid when field_type is select' do
          custom_field.field_type = :single_select

          expect(custom_field).to be_valid
        end

        it 'is valid when field_type is multi_select' do
          custom_field.field_type = :multi_select

          expect(custom_field).to be_valid
        end

        it 'is invalid for non-select field types' do
          custom_field.field_type = :text

          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:field_type]).to include('does not support select options.')
        end
      end

      context 'when there are no select options' do
        it 'is valid for non-select field types' do
          custom_field.field_type = :text

          expect(custom_field).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }

    let_it_be(:custom_field) { create(:custom_field, namespace: group, name: 'ZZZ') }
    let_it_be(:custom_field_2) { create(:custom_field, namespace: group, name: 'CCC') }
    let_it_be(:custom_field_archived) { create(:custom_field, :archived, namespace: group, name: 'AAA') }
    let_it_be(:other_custom_field) { create(:custom_field, namespace: create(:group), name: 'BBB') }

    describe '.of_namespace' do
      it 'returns custom fields of the given namespace' do
        expect(described_class.of_namespace(group)).to contain_exactly(
          custom_field, custom_field_2, custom_field_archived
        )
      end
    end

    describe '.active' do
      it 'returns active fields' do
        expect(described_class.active).to contain_exactly(
          custom_field, custom_field_2, other_custom_field
        )
      end
    end

    describe '.archived' do
      it 'returns archived fields' do
        expect(described_class.archived).to contain_exactly(
          custom_field_archived
        )
      end
    end

    describe '.ordered_by_status_and_name' do
      it 'returns active fields first, ordered by name' do
        expect(described_class.ordered_by_status_and_name).to eq([
          other_custom_field, custom_field_2, custom_field, custom_field_archived
        ])
      end
    end

    describe ".of_field_type" do
      let_it_be(:custom_field_number) { create(:custom_field, :number, namespace: group) }

      it "returns custom field of a given field type" do
        expect(described_class.of_field_type("number")).to contain_exactly(custom_field_number)
      end
    end

    describe 'work item type scopes' do
      let_it_be(:issue_type) { create(:work_item_type, :issue) }
      let_it_be(:task_type) { create(:work_item_type, :task) }

      before_all do
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

        create(:work_item_type_custom_field, custom_field: custom_field_2, work_item_type: issue_type)
      end

      describe '.without_any_work_item_types' do
        it 'returns custom fields that are not associated with any work item type' do
          expect(described_class.without_any_work_item_types).to contain_exactly(
            custom_field_archived, other_custom_field
          )
        end
      end

      describe '.with_work_item_types' do
        context 'with empty array' do
          it 'returns custom fields that are not associated with any work item type' do
            expect(described_class.with_work_item_types([])).to contain_exactly(
              custom_field_archived, other_custom_field
            )
          end
        end

        context 'with array of work item type IDs' do
          it 'returns custom fields that match any of the work item type IDs' do
            expect(
              described_class.with_work_item_types([issue_type.id, task_type.id])
            ).to contain_exactly(custom_field, custom_field_2)
          end
        end

        context 'with array of work item type objects' do
          it 'returns custom fields that match any of the work item types' do
            expect(described_class.with_work_item_types([issue_type, task_type])).to contain_exactly(
              custom_field, custom_field_2
            )
          end
        end
      end
    end
  end

  describe '#active?' do
    it 'returns true when archived_at is nil' do
      field = build(:custom_field, archived_at: nil)

      expect(field.active?).to eq(true)
    end

    it 'returns false when archived_at is set' do
      field = build(:custom_field, archived_at: Time.current)

      expect(field.active?).to eq(false)
    end
  end

  describe '#field_type_select?' do
    it 'returns true for single select types' do
      field = build(:custom_field, field_type: :single_select)

      expect(field.field_type_select?).to eq(true)
    end

    it 'returns true for multi select types' do
      field = build(:custom_field, field_type: :multi_select)

      expect(field.field_type_select?).to eq(true)
    end

    it 'returns false for other types' do
      field = build(:custom_field, field_type: :text)

      expect(field.field_type_select?).to eq(false)
    end
  end
end
