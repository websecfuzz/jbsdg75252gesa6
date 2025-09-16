# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::RelatedWorkItemLink, feature_category: :portfolio_management do
  it_behaves_like 'includes LinkableItem concern (EE)' do
    let_it_be(:item_factory) { :work_item }
    let_it_be(:link_factory) { :work_item_link }
    let_it_be(:link_class) { described_class }
  end

  describe 'associations' do
    it do
      is_expected.to have_one(:related_epic_link).class_name('::Epic::RelatedEpicLink')
        .with_foreign_key('issue_link_id').inverse_of(:related_work_item_link)
    end
  end

  describe 'scopes' do
    let(:epic_type) { ::WorkItems::Type.default_by_type(:epic) }

    let_it_be(:epic_issue_link) do
      create(:work_item_link, source: create(:work_item, :epic), target: create(:work_item, :issue))
    end

    let_it_be(:epic_epic_link) do
      create(:work_item_link, source: create(:work_item, :epic), target: create(:work_item, :epic))
    end

    let_it_be(:issue_epic_link) do
      create(:work_item_link, source: create(:work_item, :issue), target: create(:work_item, :epic))
    end

    context 'when filtered by source type' do
      it 'returns only links with the given type on the source' do
        expect(described_class.for_source_type(epic_type)).to contain_exactly(epic_issue_link, epic_epic_link)
      end
    end

    context 'when filtered by target type' do
      it 'returns only links with the given type on the target' do
        expect(described_class.for_target_type(epic_type)).to contain_exactly(issue_epic_link, epic_epic_link)
      end
    end

    context 'when combining for_target_type and for_source_type' do
      it 'returns only links with the given type on the source and target' do
        expect(described_class.for_source_type(epic_type).for_target_type(epic_type)).to contain_exactly(epic_epic_link)
      end
    end
  end

  describe 'validations' do
    describe '#validate_related_link_restrictions' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:project) { create(:project) }

      def get_items(type_names = [], all_types: false, with_unsupported_types: false)
        if all_types
          %i[ticket requirement incident test_case task issue epic objective key_result]
        elsif with_unsupported_types
          type_names + %i[requirement test_case ticket]
        else
          type_names
        end
      end

      def restriction_error(source, target, action = 'be related to')
        format(
          "%{source_name} cannot %{action} %{target_name}",
          source_name: source.work_item_type.name.downcase.pluralize,
          target_name: target.work_item_type.name.downcase.pluralize,
          action: action
        )
      end

      where(:source_type_sym, :target_types, :valid) do
        :requirement | get_items(all_types: true)                          | false
        :objective   | get_items(with_unsupported_types: true)             | false
        :key_result  | get_items(with_unsupported_types: true)             | false
        :epic        | get_items(with_unsupported_types: true)             | false
        :objective   | get_items(%i[task issue epic objective key_result]) | true
        :key_result  | get_items(%i[task issue epic key_result])           | true
        :epic        | get_items(%i[task issue epic])                      | true
      end

      with_them do
        it 'validates the related link' do
          target_types.each do |target_type_sym|
            source_type = WorkItems::Type.default_by_type(source_type_sym)
            target_type = WorkItems::Type.default_by_type(target_type_sym)
            source = build(:work_item, work_item_type: source_type, project: project)
            target = build(:work_item, work_item_type: target_type, project: project)
            link = build(:work_item_link, source: source, target: target)
            opposite_link = build(:work_item_link, source: target, target: source)

            expect(link.valid?).to eq(valid)
            expect(opposite_link.valid?).to eq(valid)
            next if valid

            expect(link.errors.messages[:source]).to contain_exactly(restriction_error(source, target))
          end
        end
      end

      context 'when validating ability to block other items' do
        where(:source_type_sym, :target_types, :valid) do
          :requirement | get_items(all_types: true)                                   | false
          :incident    | get_items(with_unsupported_types: true)                      | false
          :test_case   | get_items(all_types: true)                                   | false
          :ticket      | get_items(all_types: true)                                   | false
          :issue       | get_items(with_unsupported_types: true)                      | false
          :epic        | get_items(with_unsupported_types: true)                      | false
          :task        | get_items(with_unsupported_types: true)                      | false
          :objective   | get_items(%i[epic issue task], with_unsupported_types: true) | false
          :key_result  | get_items(%i[epic issue task], with_unsupported_types: true) | false
          :issue       | get_items(%i[task issue epic objective key_result])          | true
          :epic        | get_items(%i[task issue epic objective key_result])          | true
          :task        | get_items(%i[task issue epic objective key_result])          | true
          :objective   | get_items(%i[objective key_result])                          | true
          :key_result  | get_items(%i[objective key_result])                          | true
        end

        with_them do
          it 'validates the blocking link' do
            target_types.each do |target_type_sym|
              source_type = WorkItems::Type.default_by_type(source_type_sym)
              target_type = WorkItems::Type.default_by_type(target_type_sym)
              source = build(:work_item, work_item_type: source_type, project: project)
              target = build(:work_item, work_item_type: target_type, project: project)
              link = build(:work_item_link, source: source, target: target, link_type: 'blocks')

              expect(link.valid?).to eq(valid)
              next if valid

              expect(link.errors.messages[:source]).to contain_exactly(restriction_error(source, target, 'block'))
            end
          end
        end
      end

      context 'when validating ability to be blocked by other items' do
        where(:source_type_sym, :target_types, :valid) do
          :requirement | get_items(all_types: true)                                        | false
          :incident    | get_items(with_unsupported_types: true)                           | false
          :test_case   | get_items(all_types: true)                                        | false
          :ticket      | get_items(all_types: true)                                        | false
          :issue       | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :epic        | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :task        | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :objective   | get_items(with_unsupported_types: true)                           | false
          :key_result  | get_items(with_unsupported_types: true)                           | false
          :issue       | get_items(%i[task issue epic])                                    | true
          :epic        | get_items(%i[task issue epic])                                    | true
          :task        | get_items(%i[task issue epic])                                    | true
          :objective   | get_items(%i[epic issue task objective key_result])               | true
          :key_result  | get_items(%i[epic issue task objective key_result])               | true
        end

        with_them do
          it 'validates the related link' do
            target_types.each do |target_type_sym|
              source_type = WorkItems::Type.default_by_type(source_type_sym)
              target_type = WorkItems::Type.default_by_type(target_type_sym)
              source = build(:work_item, work_item_type: source_type, project: project)
              target = build(:work_item, work_item_type: target_type, project: project)

              link = build(:work_item_link, source: target, target: source, link_type: 'blocks')

              expect(link.valid?).to eq(valid)
              next if valid

              expect(link.errors.messages[:source]).to contain_exactly(restriction_error(target, source, 'block'))
            end
          end
        end
      end
    end
  end

  describe '#synced_related_epic_link' do
    let_it_be(:group) { create(:group) }
    let_it_be(:epic_a) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:epic_b) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:work_item_a) { epic_a.work_item }
    let_it_be(:work_item_b) { epic_b.work_item }
    let_it_be_with_refind(:link) { create(:work_item_link, source: work_item_a, target: work_item_b) }

    subject(:related_epic_link) { link.synced_related_epic_link }

    it { is_expected.to be_nil }

    context 'when there is a synced related epic record' do
      let_it_be(:related_epic_link) do
        create(:related_epic_link, source: epic_a, target: epic_b, related_work_item_link: link)
      end

      it { is_expected.to eq(related_epic_link) }
    end
  end
end
