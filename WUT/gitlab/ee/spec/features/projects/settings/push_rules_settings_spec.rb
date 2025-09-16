# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project settings > [EE] repository', feature_category: :code_review_workflow do
  let(:user) { create(:user) }
  let(:project) { create(:project_empty_repo) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  describe 'editing a push rule' do
    let(:commit_message) { 'Required part of every message' }
    let(:input_id) { 'push_rule_commit_message_regex' }

    context 'push rules licensed' do
      before do
        visit project_settings_repository_path(project)

        fill_in input_id, with: commit_message
        click_button 'Save push rules'
      end

      it 'displays the new value in the form' do
        expect(find("##{input_id}").value).to eq commit_message
      end

      it 'saves the new value' do
        expect(project.push_rule.commit_message_regex).to eq commit_message
      end
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)

        visit project_settings_repository_path(project)
      end

      it 'hides push rule settings' do
        expect(page).not_to have_content('Push rules')
      end
    end
  end
end
