# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::WorkItemsResolver do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, reporter_of: project) }

  describe '#resolve', :aggregate_failures do
    let_it_be(:work_item1) { create(:work_item, :satisfied_status, project: project) }
    let_it_be(:work_item2) { create(:work_item, :failed_status, project: project, health_status: :at_risk, weight: 1) }
    let_it_be(:work_item3) { create(:work_item, :requirement, project: project, health_status: :on_track, weight: 2) }

    context 'with verification status widget arguments', feature_category: :requirements_management do
      it 'filters work items by verification status' do
        expect(resolve_items(verification_status_widget: { verification_status: 'passed' }))
          .to contain_exactly(work_item1)

        expect(resolve_items(verification_status_widget: { verification_status: 'failed' }))
          .to contain_exactly(work_item2)

        expect(resolve_items(verification_status_widget: { verification_status: 'missing' }))
          .to contain_exactly(work_item3)
      end

      context 'when work_items_alpha flag is disabled' do
        before do
          stub_feature_flags(work_items_alpha: false)
        end

        it 'ignores verification_status_widget argument' do
          expect(resolve_items(verification_status_widget: { verification_status: 'passed' }))
            .to contain_exactly(work_item1, work_item2, work_item3)
        end
      end
    end

    context 'with health_status filter', feature_category: :requirements_management do
      it 'filters work items by health_status' do
        expect(resolve_items(health_status_filter: :at_risk)).to contain_exactly(work_item2)
        expect(resolve_items(health_status_filter: :on_track)).to contain_exactly(work_item3)

        expect(resolve_items(health_status_filter: :any)).to contain_exactly(work_item2, work_item3)
        expect(resolve_items(health_status_filter: :none)).to contain_exactly(work_item1)
      end
    end

    context 'with negated health_status filter', feature_category: :requirements_management do
      it 'excludes work items by health_status' do
        expect(resolve_items(not: { health_status_filter: [:at_risk] }))
          .to contain_exactly(work_item1, work_item3)

        expect(resolve_items(not: { health_status_filter: [:on_track] }))
          .to contain_exactly(work_item1, work_item2)

        expect(resolve_items(not: { health_status_filter: [:at_risk, :on_track] }))
          .to contain_exactly(work_item1)
      end
    end

    context 'with weight filter', feature_category: :requirements_management do
      it 'filters work items by weight' do
        expect(resolve_items(weight: '1')).to contain_exactly(work_item2)
        expect(resolve_items(weight: '2')).to contain_exactly(work_item3)

        expect(resolve_items(weight: 'any')).to contain_exactly(work_item2, work_item3)
        expect(resolve_items(weight: 'none')).to contain_exactly(work_item1)
      end
    end

    context 'with weight wildcard filter', feature_category: :requirements_management do
      it 'filters work items by weight wildcard' do
        expect(resolve_items(weight_wildcard_id: 'ANY')).to contain_exactly(work_item2, work_item3)
        expect(resolve_items(weight_wildcard_id: 'NONE')).to contain_exactly(work_item1)
      end
    end

    context 'with negated weight filter', feature_category: :requirements_management do
      it 'excludes work items by weight' do
        expect(resolve_items(not: { weight: '1' }))
          .to contain_exactly(work_item1, work_item3)

        expect(resolve_items(not: { weight: '2' }))
          .to contain_exactly(work_item1, work_item2)
      end
    end

    context 'with combined filters', feature_category: :requirements_management do
      it 'combines weight and health_status filters' do
        expect(resolve_items(weight: 'any', health_status_filter: :at_risk))
          .to contain_exactly(work_item2)
      end

      it 'combines regular and negated filters' do
        # Has weight but not at_risk health status
        expect(resolve_items(weight: 'any', not: { health_status_filter: [:at_risk] }))
          .to contain_exactly(work_item3)
      end

      it 'combines weight wildcard with other filters' do
        expect(resolve_items(weight_wildcard_id: 'ANY', health_status_filter: :on_track))
          .to contain_exactly(work_item3)
      end
    end

    context 'with iteration filters', feature_category: :requirements_management do
      let_it_be(:cadence) { create(:iterations_cadence, group: group) }
      let_it_be(:iteration1) do
        create(:iteration, iterations_cadence: cadence, start_date: 4.weeks.ago, due_date: 3.weeks.ago)
      end

      let_it_be(:iteration2) do
        create(:iteration, iterations_cadence: cadence, start_date: 6.weeks.ago, due_date: 5.weeks.ago)
      end

      let_it_be(:current_iteration) do
        create(:iteration, iterations_cadence: cadence, start_date: 2.days.ago, due_date: 1.day.from_now)
      end

      let_it_be(:upcoming_iteration) do
        create(:iteration, iterations_cadence: cadence, start_date: 1.week.from_now, due_date: 2.weeks.from_now)
      end

      let_it_be(:work_item_with_iteration1) { create(:work_item, project: project, iteration: iteration1) }
      let_it_be(:work_item_with_iteration2) { create(:work_item, project: project, iteration: iteration2) }
      let_it_be(:work_item_with_current_iteration) do
        create(:work_item, project: project, iteration: current_iteration)
      end

      let_it_be(:work_item_with_upcoming_iteration) do
        create(:work_item, project: project, iteration: upcoming_iteration)
      end

      let_it_be(:work_item_without_iteration) { create(:work_item, project: project) }

      describe 'filtering by iteration_id' do
        it 'returns work items with iteration using raw id' do
          expect(resolve_items(iteration_id: [iteration1.id])).to contain_exactly(work_item_with_iteration1)
        end

        it 'returns work items with iteration using global id' do
          expect(resolve_items(iteration_id: [iteration1.to_global_id])).to contain_exactly(work_item_with_iteration1)
        end

        it 'returns work items with multiple iterations using global ids' do
          expect(resolve_items(iteration_id: [iteration1.to_global_id, iteration2.to_global_id]))
            .to contain_exactly(work_item_with_iteration1, work_item_with_iteration2)
        end

        it 'returns work items with multiple iterations using a mix of raw and global ids' do
          expect(resolve_items(iteration_id: [iteration1.id, iteration2.to_global_id]))
            .to contain_exactly(work_item_with_iteration1, work_item_with_iteration2)
        end

        it 'returns work items with upcoming iteration' do
          expect(resolve_items(iteration_id: [upcoming_iteration.to_global_id]))
            .to contain_exactly(work_item_with_upcoming_iteration)
        end
      end

      describe 'filtering by iteration wildcard' do
        it 'returns work items with current iteration' do
          expect(resolve_items(iteration_wildcard_id: 'CURRENT')).to contain_exactly(work_item_with_current_iteration)
        end

        it 'returns work items with any iteration' do
          expect(resolve_items(iteration_wildcard_id: 'ANY'))
            .to contain_exactly(work_item_with_iteration1, work_item_with_iteration2, work_item_with_current_iteration,
              work_item_with_upcoming_iteration)
        end

        it 'returns work items with no iteration' do
          expect(resolve_items(iteration_wildcard_id: 'NONE'))
            .to contain_exactly(work_item1, work_item2, work_item3, work_item_without_iteration)
        end

        it 'generates mutually exclusive filter error when wildcard and list are provided' do
          expect_graphql_error_to_be_created(
            GraphQL::Schema::Validator::ValidationFailedError,
            'Only one of [iterationId, iterationWildcardId] arguments is allowed at the same time.'
          ) do
            resolve_items(iteration_id: [iteration1.to_global_id], iteration_wildcard_id: 'CURRENT')
          end
        end
      end

      describe 'filtering by iteration_cadence_id' do
        let_it_be(:other_cadence) { create(:iterations_cadence, group: group) }
        let_it_be(:other_iteration) { create(:iteration, iterations_cadence: other_cadence) }
        let_it_be(:work_item_with_other_cadence) { create(:work_item, project: project, iteration: other_iteration) }

        it 'returns work items with iterations from specific cadence' do
          expect(resolve_items(iteration_cadence_id: [cadence.to_global_id]))
            .to contain_exactly(work_item_with_iteration1, work_item_with_iteration2,
              work_item_with_current_iteration, work_item_with_upcoming_iteration)
        end

        it 'returns work items with iterations from multiple cadences' do
          expect(resolve_items(iteration_cadence_id: [cadence.to_global_id, other_cadence.to_global_id]))
            .to contain_exactly(
              work_item_with_iteration1,
              work_item_with_iteration2,
              work_item_with_current_iteration,
              work_item_with_other_cadence,
              work_item_with_upcoming_iteration
            )
        end
      end

      describe 'filtering by negated iteration' do
        it 'returns work items without the specified iteration using raw id' do
          expect(resolve_items(not: { iteration_id: [iteration1.id.to_s] }))
            .to contain_exactly(
              work_item1, work_item2, work_item3,
              work_item_with_iteration2, work_item_with_current_iteration, work_item_without_iteration,
              work_item_with_upcoming_iteration
            )
        end

        it 'returns work items without the specified iteration using global id' do
          expect(resolve_items(not: { iteration_id: [iteration1.to_global_id] }))
            .to contain_exactly(
              work_item1, work_item2, work_item3,
              work_item_with_iteration2, work_item_with_current_iteration, work_item_without_iteration,
              work_item_with_upcoming_iteration
            )
        end

        it 'returns work items without multiple specified iterations' do
          expect(resolve_items(not: { iteration_id: [iteration1.to_global_id, iteration2.to_global_id] }))
            .to contain_exactly(
              work_item1, work_item2, work_item3,
              work_item_with_current_iteration, work_item_without_iteration, work_item_with_upcoming_iteration
            )
        end
      end

      it 'handles invalid global IDs gracefully' do
        invalid_id = 'invalid_global_id_format'

        expect(resolve_items(iteration_id: [invalid_id])).to be_empty

        expect(resolve_items(iteration_id: [iteration1.to_global_id, invalid_id]))
          .to contain_exactly(work_item_with_iteration1)
      end

      describe 'filtering by iteration_cadence_id with invalid IDs' do
        it 'handles invalid global IDs gracefully' do
          invalid_id = 'invalid_cadence_global_id'

          expect(resolve_items(iteration_cadence_id: [invalid_id])).to be_empty

          expect(resolve_items(iteration_cadence_id: [cadence.to_global_id, invalid_id]))
            .to contain_exactly(work_item_with_iteration1, work_item_with_iteration2,
              work_item_with_current_iteration, work_item_with_upcoming_iteration)
        end
      end
    end

    context 'with legacy requirement widget arguments', feature_category: :requirements_management do
      let_it_be(:work_item_from_other_project) do
        create(:work_item, :requirement, project: create(:project), iid: work_item1.iid)
      end

      it 'filters work items by legacy iid' do
        expect(resolve_items(
          requirement_legacy_widget: { legacy_iids: [work_item1.requirement.iid.to_s] }
        )).to contain_exactly(work_item1)

        expect(resolve_items(
          requirement_legacy_widget: { legacy_iids: [work_item1.requirement.iid.to_s, work_item2.requirement.iid.to_s] }
        )).to contain_exactly(work_item1, work_item2)

        expect(resolve_items(
          requirement_legacy_widget: { legacy_iids: ['nonsense'] }
        )).to be_empty
      end
    end
  end

  def resolve_items(args = {}, context = { current_user: user })
    resolve(described_class, obj: project, args: args, ctx: context, arg_style: :internal)
  end
end
