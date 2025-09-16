# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::WorkItemsHelper, feature_category: :team_planning do
  include Devise::Test::ControllerHelpers

  describe '#work_items_data' do
    subject(:work_items_data) { helper.work_items_data(project, current_user) }

    before do
      stub_licensed_features(
        blocked_issues: feature_available,
        group_bulk_edit: feature_available,
        issuable_health_status: feature_available,
        iterations: feature_available,
        issue_weights: feature_available,
        okrs: feature_available,
        subepics: feature_available,
        epics: feature_available,
        quality_management: feature_available,
        scoped_labels: feature_available,
        linked_items_epics: feature_available
      )
      allow(helper).to receive(:can?).and_call_original
      allow(helper).to receive(:can?).with(current_user, :bulk_admin_epic, project).and_return(feature_available)
    end

    let_it_be(:group) { build(:group) }
    let_it_be(:project) { build(:project, group: group) }
    let_it_be(:current_user) { build(:user, owner_of: project) }

    context 'when features are available' do
      let(:feature_available) { true }

      it 'returns true for the features' do
        expect(work_items_data).to include(
          {
            has_blocked_issues_feature: "true",
            has_group_bulk_edit_feature: "true",
            has_issuable_health_status_feature: "true",
            has_issue_weights_feature: "true",
            has_iterations_feature: "true",
            has_okrs_feature: "true",
            has_subepics_feature: "true",
            has_epics_feature: "true",
            has_scoped_labels_feature: "true",
            has_quality_management_feature: "true",
            can_bulk_edit_epics: "true",
            group_issues_path: issues_group_path(project),
            labels_fetch_path: group_labels_path(
              project, format: :json, only_group_labels: true, include_ancestor_groups: true
            ),
            new_comment_template_paths: include({ text: "Your comment templates",
                                                  href: profile_comment_templates_path }.to_json),
            epics_list_path: group_epics_path(project),
            has_linked_items_epics_feature: "true"
          })
      end
    end

    context 'when feature not available' do
      let(:feature_available) { false }

      it 'returns false for the features' do
        expect(work_items_data).to include(
          {
            has_blocked_issues_feature: "false",
            has_group_bulk_edit_feature: "false",
            has_issuable_health_status_feature: "false",
            has_issue_weights_feature: "false",
            has_iterations_feature: "false",
            has_okrs_feature: "false",
            has_subepics_feature: "false",
            has_epics_feature: "false",
            has_scoped_labels_feature: "false",
            has_quality_management_feature: "false",
            can_bulk_edit_epics: "false",
            has_linked_items_epics_feature: "false"
          }
        )
      end
    end
  end

  describe '#add_work_item_show_breadcrumb' do
    subject(:add_work_item_show_breadcrumb) { helper.add_work_item_show_breadcrumb(resource_parent, work_item.iid) }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for querying the work item type
    let_it_be(:resource_parent) { create(:group) }

    context 'when an epic' do
      let(:work_item) { create(:work_item, :epic, namespace: resource_parent) }

      it 'adds the correct breadcrumb' do
        expect(helper).to receive(:add_to_breadcrumbs).with('Epics', group_epics_path(resource_parent))

        add_work_item_show_breadcrumb
      end
    end
    # rubocop:enable RSpec/FactoryBot/AvoidCreate
  end
end
