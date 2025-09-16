# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::IssuesHelper, feature_category: :team_planning do
  let_it_be(:group) { create :group }
  let_it_be(:project) { create :project, group: group }
  let_it_be(:issue) { create :issue, project: project }

  describe '#issue_in_subepic?' do
    let_it_be(:epic) { create(:epic) }
    let_it_be(:epic_issue) { create(:epic_issue, epic: epic, issue: issue) }
    let_it_be(:new_issue) { create(:issue, project: project) }

    it 'returns false if epic_id parameter is not set or is wildcard' do
      ['', nil, 'none', 'any'].each do |epic_id|
        expect(helper.issue_in_subepic?(issue, epic_id)).to be_falsy
      end
    end

    it 'returns false if epic_id parameter is the same as issue epic_id' do
      expect(helper.issue_in_subepic?(issue, epic.id)).to be_falsy
    end

    it 'returns false if the issue is not part of an epic' do
      expect(helper.issue_in_subepic?(new_issue, epic.id)).to be_falsy
    end

    it 'returns true if epic_id parameter is not the same as issue epic_id' do
      # When issue_in_subepic? is used, any epic with a different
      # id than the one on the params is considered a child
      expect(helper.issue_in_subepic?(issue, 'subepic_id')).to be_truthy
    end
  end

  describe '#show_timeline_view_toggle?' do
    subject { helper.show_timeline_view_toggle?(issue) }

    it { is_expected.to be_falsy }

    context 'issue is an incident' do
      let(:issue) { build_stubbed(:incident) }

      it { is_expected.to be_falsy }

      context 'with license' do
        before do
          stub_licensed_features(incident_timeline_view: true)
        end

        it { is_expected.to be_truthy }

        context 'when issue is created at the group level' do
          let(:issue) { build_stubbed(:issue, :incident, :group_level) }

          it { is_expected.to be_truthy }
        end

        context 'when issue is created at the user namespace level' do
          let(:issue) { build_stubbed(:issue, :incident, :user_namespace_level) }

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#scoped_labels_available?' do
    shared_examples 'without license' do
      before do
        stub_licensed_features(scoped_labels: false)
      end

      it { is_expected.to be_falsy }
    end

    shared_examples 'with license' do
      before do
        stub_licensed_features(scoped_labels: true)
      end

      it { is_expected.to be_truthy }
    end

    context 'project' do
      subject { helper.scoped_labels_available?(project) }

      it_behaves_like 'without license'
      it_behaves_like 'with license'
    end

    context 'group' do
      subject { helper.scoped_labels_available?(group) }

      it_behaves_like 'without license'
      it_behaves_like 'with license'
    end
  end

  describe '#project_issues_list_data' do
    let(:current_user) { double.as_null_object }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:url_for).and_return('#')
      allow(helper).to receive(:import_csv_namespace_project_issues_path).and_return('#')
    end

    context 'when features are enabled' do
      before do
        stub_licensed_features(
          blocked_issues: true,
          custom_fields: true,
          epics: true,
          issuable_health_status: true,
          issue_weights: true,
          iterations: true,
          okrs: true,
          quality_management: true,
          scoped_labels: true
        )
      end

      it 'returns data with licensed features enabled' do
        expected = {
          has_blocked_issues_feature: 'true',
          has_custom_fields_feature: 'true',
          has_issuable_health_status_feature: 'true',
          has_issue_weights_feature: 'true',
          has_iterations_feature: 'true',
          has_okrs_feature: 'true',
          has_quality_management_feature: 'true',
          has_scoped_labels_feature: 'true',
          group_path: project.group.full_path
        }

        expect(helper.project_issues_list_data(project, current_user)).to include(expected)
      end

      context 'when project does not have group' do
        let(:project_with_no_group) { create :project }

        it 'does not return group_path' do
          expect(helper.project_issues_list_data(project_with_no_group, current_user)).not_to include(:group_path)
        end
      end
    end

    context 'when features are disabled' do
      before do
        stub_licensed_features(
          blocked_issues: false,
          custom_fields: false,
          epics: false,
          issuable_health_status: false,
          issue_weights: false,
          iterations: false,
          okrs: false,
          quality_management: false,
          scoped_labels: false
        )
      end

      it 'returns data with licensed features disabled' do
        expected = {
          has_blocked_issues_feature: 'false',
          has_custom_fields_feature: 'false',
          has_issuable_health_status_feature: 'false',
          has_issue_weights_feature: 'false',
          has_iterations_feature: 'false',
          has_okrs_feature: 'false',
          has_quality_management_feature: 'false',
          has_scoped_labels_feature: 'false'
        }

        result = helper.project_issues_list_data(project, current_user)

        expect(result).to include(expected)
        expect(result).not_to include(:group_path)
      end
    end
  end

  describe '#group_issues_list_data' do
    let(:current_user) { double.as_null_object }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:url_for).and_return('#')
    end

    context 'when features are enabled' do
      before do
        stub_licensed_features(
          blocked_issues: true,
          custom_fields: true,
          epics: true,
          group_bulk_edit: true,
          issuable_health_status: true,
          issue_weights: true,
          iterations: true,
          okrs: true,
          quality_management: true,
          scoped_labels: true
        )
      end

      it 'returns data with licensed features enabled' do
        expected = {
          can_bulk_update: 'true',
          has_blocked_issues_feature: 'true',
          has_custom_fields_feature: 'true',
          has_issuable_health_status_feature: 'true',
          has_issue_weights_feature: 'true',
          has_iterations_feature: 'true',
          has_okrs_feature: 'true',
          has_quality_management_feature: 'true',
          has_scoped_labels_feature: 'true',
          group_path: project.group.full_path
        }

        expect(helper.group_issues_list_data(group, current_user)).to include(expected)
      end
    end

    context 'when features are disabled' do
      before do
        stub_licensed_features(
          blocked_issues: false,
          custom_fields: false,
          epics: false,
          group_bulk_edit: false,
          issuable_health_status: false,
          issue_weights: false,
          iterations: false,
          okrs: false,
          quality_management: false,
          scoped_labels: false
        )
      end

      it 'returns data with licensed features disabled' do
        expected = {
          can_bulk_update: 'false',
          has_blocked_issues_feature: 'false',
          has_custom_fields_feature: 'false',
          has_issuable_health_status_feature: 'false',
          has_issue_weights_feature: 'false',
          has_iterations_feature: 'false',
          has_okrs_feature: 'false',
          has_quality_management_feature: 'false',
          has_scoped_labels_feature: 'false'
        }

        result = helper.group_issues_list_data(group, current_user)

        expect(result).to include(expected)
        expect(result).not_to include(:group_path)
      end
    end
  end

  describe '#dashboard_issues_list_data' do
    let(:current_user) { double.as_null_object }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow(helper).to receive(:image_path).and_return('#')
      allow(helper).to receive(:url_for).and_return('#')
    end

    context 'when features are enabled' do
      before do
        stub_licensed_features(
          blocked_issues: true,
          issuable_health_status: true,
          issue_weights: true,
          okrs: true,
          quality_management: true,
          scoped_labels: true
        )
      end

      it 'returns data with licensed features enabled' do
        expected = {
          has_blocked_issues_feature: 'true',
          has_issuable_health_status_feature: 'true',
          has_issue_weights_feature: 'true',
          has_okrs_feature: 'true',
          has_quality_management_feature: 'true',
          has_scoped_labels_feature: 'true'
        }

        expect(helper.dashboard_issues_list_data(current_user)).to include(expected)
      end
    end

    context 'when features are disabled' do
      before do
        stub_licensed_features(
          blocked_issues: false,
          issuable_health_status: false,
          issue_weights: false,
          okrs: false,
          quality_management: false,
          scoped_labels: false
        )
      end

      it 'returns data with licensed features disabled' do
        expected = {
          has_blocked_issues_feature: 'false',
          has_issuable_health_status_feature: 'false',
          has_issue_weights_feature: 'false',
          has_okrs_feature: 'false',
          has_quality_management_feature: 'false',
          has_scoped_labels_feature: 'false'
        }

        expect(helper.dashboard_issues_list_data(current_user)).to include(expected)
      end
    end
  end
end
