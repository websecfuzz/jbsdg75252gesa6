# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Push rules', :js, feature_category: :code_review_workflow do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:foo) { { reject_unsigned_commits: 'Reject unsigned commits' } }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  push_rules_with_titles = {
    reject_unsigned_commits: 'Reject unsigned commits',
    commit_committer_check: 'Reject unverified users'
  }

  push_rules_with_titles.each do |rule_attr, title|
    describe "#{rule_attr} rule" do
      context 'unlicensed' do
        before do
          stub_licensed_features(rule_attr => false)
        end

        it 'does not render the setting checkbox' do
          visit project_settings_repository_path(project)

          expect(page).not_to have_content(title)
        end
      end

      context 'licensed' do
        let(:bronze_plan) { create(:bronze_plan) }
        let(:ultimate_plan) { create(:ultimate_plan) }

        before do
          stub_licensed_features(rule_attr => true)
        end

        it 'renders the setting checkbox' do
          visit project_settings_repository_path(project)

          expect(page).to have_content(title)
        end

        describe 'with GL.com plans', :saas do
          before do
            stub_application_setting(check_namespace_plan: true)
          end

          context 'when disabled' do
            it 'does not render the setting checkbox' do
              create(:gitlab_subscription, :bronze, namespace: project.namespace)

              visit project_settings_repository_path(project)

              expect(page).not_to have_content(title)
            end
          end

          context 'when enabled' do
            it 'renders the setting checkbox' do
              create(:gitlab_subscription, :ultimate, namespace: project.namespace)

              visit project_settings_repository_path(project)

              expect(page).to have_content(title)
            end
          end
        end
      end
    end
  end
end
