# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::GetStartedPresenter, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:group) }
  let(:project) { build(:project, namespace: namespace) }
  let(:onboarding_progress) { build(:onboarding_progress, namespace: namespace) }
  let(:user) { build(:user) }
  let(:presenter) { described_class.new(user, project, onboarding_progress) }
  let(:parsed_attributes) { Gitlab::Json.parse(attributes) }
  let(:sections) { parsed_attributes['sections'] }

  describe '#attributes' do
    subject(:attributes) { presenter.attributes }

    it 'returns a JSON string with all attributes' do
      expect(attributes).to be_a(String)
      expect(parsed_attributes).to include('projectName', 'sections')
    end

    it 'includes all required sections' do
      expect(sections.size).to eq(4)

      titles = [
        s_('LearnGitLab|Set up your code'),
        s_('LearnGitLab|Configure a project'),
        s_('LearnGitLab|Plan and execute work together'),
        s_('LearnGitLab|Secure your deployment')
      ]
      expect(sections.pluck('title')).to eq(titles)
    end

    it 'has correct structure for all sections' do
      expect(sections).to all(include('title', 'description', 'actions'))

      structure = ->(section) {
        section['title'].is_a?(String) && section['description'].is_a?(String) && section['actions'].is_a?(Array)
      }

      expect(sections).to all(satisfy(&structure))

      actions_structure = ->(action) do
        action['title'].is_a?(String) &&
          action['trackLabel'].is_a?(String) &&
          action['url'].is_a?(String) &&
          (action['completed'].is_a?(TrueClass) || action['completed'].is_a?(FalseClass))
      end

      expect(sections.flat_map { |section| section['actions'] }).to all(satisfy(&actions_structure))
      expect(sections.find { |section| section['trialActions'] }&.fetch('trialActions'))
        .to all(satisfy(&actions_structure))
    end

    context 'for projectName' do
      it 'includes project name' do
        expect(parsed_attributes['projectName']).to eq(project.name)
      end
    end

    context 'for code section' do
      subject(:actions) { sections.first['actions'] }

      it 'marks all actions initially as uncompleted' do
        expect(actions).to all(include('completed' => false))
      end

      context 'when actions are completed' do
        before do
          onboarding_progress.code_added_at = Time.current
          onboarding_progress.created_at = Time.current
        end

        it 'marks actions as completed' do
          expect(actions).to all(include('completed' => true))
        end
      end
    end

    context 'for project section' do
      let(:trial_actions) { section['trialActions'] }
      let(:actions) { section['actions'] }
      let(:invite_action) { actions.find { |action| action['urlType'] == 'invite' } }
      let(:trial_action) { find_action_by_label(actions, 'start_a_free_trial_of_gitlab_ultimate') }
      let(:duo_seat_action) { find_action_by_label(trial_actions, 'duo_seat_assigned') }

      subject(:section) { sections.second }

      it 'has trialActions' do
        expect(trial_actions).to be_an(Array)
      end

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(3)
      end

      it 'includes the correct number of trial actions' do
        expect(trial_actions.size).to eq(3)
      end

      it 'marks all actions initially as uncompleted' do
        expect(actions).to all(include('completed' => false))
        expect(trial_actions).to all(include('completed' => false))
      end

      context 'when actions are completed' do
        before do
          onboarding_progress.user_added_at = Time.current
          onboarding_progress.pipeline_created_at = Time.current
          onboarding_progress.trial_started_at = Time.current
          onboarding_progress.duo_seat_assigned_at = Time.current
          onboarding_progress.code_owners_enabled_at = Time.current
          onboarding_progress.required_mr_approvals_enabled_at = Time.current
        end

        it 'marks actions as completed' do
          expect(actions).to all(include('completed' => true))
          expect(trial_actions).to all(include('completed' => true))
        end
      end

      context 'when invite is enabled' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:invite_member, project).and_return(true)
        end

        it 'marks invite action as enabled' do
          expect(invite_action['enabled']).to be true
        end
      end

      context 'when invite is disabled' do
        it 'marks invite action as disabled' do
          expect(invite_action['enabled']).to be false
        end
      end

      context 'when user can assign duo seats' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:read_usage_quotas, namespace).and_return(true)
        end

        it 'marks action as enabled' do
          expect(duo_seat_action['enabled']).to be true
        end
      end

      context 'when user cannot assign duo seats' do
        it 'marks action as disabled' do
          expect(duo_seat_action['enabled']).to be false
        end
      end

      context 'when user can admin namespace' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:admin_namespace, namespace).and_return(true)
        end

        it 'marks trial action as enabled' do
          expect(trial_action['enabled']).to be true
        end
      end

      context 'when user cannot admin namespace' do
        it 'marks trial action as disabled' do
          expect(trial_action['enabled']).to be false
        end
      end
    end

    context 'for plan section' do
      subject(:actions) { sections.third['actions'] }

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(2)
      end

      it 'marks all actions initially as uncompleted' do
        expect(actions).to all(include('completed' => false))
      end

      context 'when actions are completed' do
        before do
          onboarding_progress.issue_created_at = Time.current
          onboarding_progress.merge_request_created_at = Time.current
        end

        it 'marks actions as completed' do
          expect(actions).to all(include('completed' => true))
        end
      end
    end

    context 'for secure deployment section' do
      let(:actions) { section['actions'] }
      let(:scan_action) { find_action_by_label(actions, 'scan_dependencies_for_vulnerabilities') }
      let(:dast_action) { find_action_by_label(actions, 'analyze_your_application_for_vulnerabilities_with_dast') }

      subject(:section) { sections.fourth }

      it 'includes the correct number of actions' do
        expect(actions.size).to eq(3)
      end

      it 'marks all actions initially as uncompleted' do
        expect(actions).to all(include('completed' => false))
      end

      context 'when actions are completed' do
        before do
          onboarding_progress.license_scanning_run_at = Time.current
          onboarding_progress.secure_dependency_scanning_run_at = Time.current
          onboarding_progress.secure_dast_run_at = Time.current
        end

        it 'marks actions as completed' do
          expect(actions).to all(include('completed' => true))
        end
      end

      context 'when user can read_project_security_dashboard' do
        before do
          allow(user).to receive(:can?)
          allow(user).to receive(:can?).with(:read_project_security_dashboard, project).and_return(true)
        end

        it 'marks scan action as enabled' do
          expect(scan_action['enabled']).to be true
        end

        it 'marks dast action as enabled' do
          expect(dast_action['enabled']).to be true
        end
      end

      context 'when user cannot read_project_security_dashboard' do
        it 'marks scan action as disabled' do
          expect(scan_action['enabled']).to be false
        end

        it 'marks dast action as disabled' do
          expect(dast_action['enabled']).to be false
        end
      end
    end

    def find_action_by_label(actions, label)
      actions.find { |a| a['trackLabel'] == label }
    end
  end
end
