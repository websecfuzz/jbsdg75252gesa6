# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Epic'], feature_category: :portfolio_management do
  include GraphqlHelpers
  include_context 'includes EpicAggregate constants'

  before do
    stub_licensed_features(epics: true)
  end

  let(:fields) do
    %i[
      id iid title titleHtml description descriptionHtml confidential state group
      parent author labels start_date start_date_is_fixed start_date_fixed
      start_date_from_milestones start_date_from_inherited_source due_date
      due_date_is_fixed due_date_fixed due_date_from_milestones due_date_from_inherited_source
      closed_at created_at updated_at children has_children has_children_within_timeframe has_issues
      has_parent web_path web_url relation_path reference issues user_permissions
      notes discussions relative_position subscribed participants
      descendant_counts descendant_weight_sum upvotes downvotes
      user_notes_count user_discussions_count health_status current_user_todos
      award_emoji events ancestors color text_color blocked blocking_count
      blocked_by_count blocked_by_epics default_project_for_issue_creation
      commenters name linked_work_items
    ]
  end

  it { expect(described_class.interfaces).to include(Types::CurrentUserTodos) }

  it { expect(described_class.interfaces).to include(Types::TodoableInterface) }

  it { expect(described_class).to expose_permissions_using(Types::PermissionTypes::Epic) }

  it { expect(described_class.graphql_name).to eq('Epic') }

  it { expect(described_class).to require_graphql_authorizations(:read_epic) }

  it { expect(described_class).to have_graphql_fields(fields) }

  it { expect(described_class).to have_graphql_field(:subscribed, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:participants, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:blocking_count, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:blocked_by_epics, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:award_emoji) }

  it { expect(described_class).to have_graphql_field(:linked_work_items, complexity: 5) }

  describe 'healthStatus' do
    let_it_be(:object) { create(:epic) }

    context 'when lazy_aggregate_epic_health_statuses enabled' do
      before do
        stub_feature_flags(lazy_aggregate_epic_health_statuses: true)
      end

      it 'uses lazy calculation' do
        expect_next_instance_of(
          Gitlab::Graphql::Aggregations::Epics::LazyEpicAggregate,
          anything,
          object.id,
          HEALTH_STATUS_SUM
        ) {}

        resolved_field = resolve_field(:health_status, object)

        expect(resolved_field).to be_kind_of(GraphQL::Execution::Lazy)
      end
    end

    context 'when lazy_aggregate_epic_health_statuses disabled' do
      before do
        stub_feature_flags(lazy_aggregate_epic_health_statuses: false)
      end

      it 'uses DescendantCountService' do
        resolved_field = resolve_field(:health_status, object)

        expect(resolved_field).to be_kind_of(Epics::DescendantCountService)
      end
    end
  end

  describe 'use work item logic to present dates' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:epic) do
      build_stubbed(
        :epic,
        start_date: 1.day.ago,
        start_date_fixed: 2.days.ago,
        start_date_is_fixed: true,
        due_date: 3.days.from_now,
        due_date_fixed: 4.days.from_now,
        due_date_is_fixed: false
      )
    end

    where(:field, :result) do
      :start_date | 2.days.ago.to_date
      :start_date_fixed | 2.days.ago.to_date
      :start_date_is_fixed | true
      :due_date | 4.days.from_now.to_date
      :due_date_fixed | 4.days.from_now.to_date
      :due_date_is_fixed | true
    end

    with_them do
      it "presents epic date field using the work item WorkItems::Widgets::StartAndDueDate logic" do
        value = resolve_field(field, epic)

        expect(value).to eq(result)
      end
    end
  end
end
