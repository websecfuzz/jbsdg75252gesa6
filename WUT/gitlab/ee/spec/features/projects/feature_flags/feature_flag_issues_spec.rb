# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Feature flag issue links', :js, feature_category: :feature_flags do
  include FeatureFlagHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, namespace: developer.namespace, developers: developer) }

  before do
    sign_in(developer)
  end

  describe 'linking a feature flag to an issue' do
    let!(:issue) do
      create(:issue, project: project, title: 'My Cool Linked Issue')
    end

    let!(:other_issue) do
      create(:issue, project: project, title: 'Another Issue')
    end

    let!(:feature_flag) do
      create(:operations_feature_flag, :new_version_flag, project: project)
    end

    shared_examples 'enabled linking' do
      it 'user can link a feature flag to an issue' do
        visit(edit_project_feature_flag_path(project, feature_flag))
        add_linked_issue_button.click
        fill_in 'add-related-issues-form-input', with: "#{issue.to_reference(project)} "
        within_testid('crud-form') do
          click_button 'Add'
        end

        expect(page).to have_text 'My Cool Linked Issue'
      end

      it 'user sees simple form without relates to / blocks / is blocked by radio buttons' do
        visit(edit_project_feature_flag_path(project, feature_flag))
        add_linked_issue_button.click

        within_testid('crud-form') do
          expect(page).to have_selector "#add-related-issues-form-input"
          expect(page).not_to have_selector "#linked-issue-type-radio"
        end
      end

      it 'autocompletes issues' do
        visit(edit_project_feature_flag_path(project, feature_flag))
        add_linked_issue_button.click
        fill_in 'add-related-issues-form-input', with: '#'

        within '#at-view-issues' do
          expect(page).to have_text 'My Cool Linked Issue'
          expect(page).to have_text 'Another Issue'
        end
      end
    end

    context 'when the feature is avaialable through license' do
      before do
        stub_licensed_features(feature_flags_related_issues: true)
      end

      it_behaves_like 'enabled linking'
    end

    context 'when the feature is avaialable through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it_behaves_like 'enabled linking'
    end

    context 'when the feature is unlicensed' do
      before do
        stub_licensed_features(feature_flags_related_issues: false)
      end

      it 'does not show the related issues widget' do
        visit(edit_project_feature_flag_path(project, feature_flag))

        expect(page).to have_text 'Strategies'
        expect(page).not_to have_selector '#related-issues'
      end
    end
  end

  describe 'unlinking a feature flag from an issue' do
    let!(:issue) do
      create(:issue, project: project, title: 'Remove This Issue')
    end

    let!(:feature_flag) do
      create(:operations_feature_flag, :new_version_flag, project: project, issues: [issue])
    end

    shared_examples 'enabled unlinking' do
      it 'user can unlink a feature flag from an issue' do
        visit(edit_project_feature_flag_path(project, feature_flag))

        expect(page).to have_text 'Remove This Issue'

        remove_linked_issue_button.click

        expect(page).not_to have_text 'Remove This Issue'
      end
    end

    context 'when the feature is avaialable through license' do
      before do
        stub_licensed_features(feature_flags_related_issues: true)
      end

      it_behaves_like 'enabled unlinking'
    end

    context 'when the feature is avaialable through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it_behaves_like 'enabled unlinking'
    end
  end
end
