# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::WelcomeCreateService, :saas, feature_category: :acquisition do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:organization) { create(:organization, users: [user]) }
  let_it_be(:existing_group) { create(:group_with_plan, plan: :free_plan, owners: user) }
  let_it_be(:existing_project) { create(:project, namespace: existing_group) }
  let_it_be(:unrelated_group) { create(:group_with_plan, plan: :free_plan) }
  let_it_be(:unrelated_project) { create(:project, namespace: unrelated_group) }
  let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

  let(:glm_params) { { glm_source: 'some-source', glm_content: 'some-content' } }
  let(:group) { build(:group) }

  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      company_name: 'Test Company',
      country: 'US',
      state: 'CA',
      project_name: 'Test Project',
      group_name: 'gitlab',
      organization_id: organization.id
    }.merge(glm_params)
  end

  let(:lead_params) do
    {
      trial_user: params.except(:namespace_id, :group_name, :project_name, :organization_id).merge(
        {
          work_email: user.email,
          uid: user.id,
          setup_for_company: false,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab'
        }
      )
    }
  end

  let(:group_params) do
    glm_params.merge(
      namespace_id: be_a(Integer),
      namespace: {
        id: be_a(Integer),
        name: be_a(String),
        path: be_a(String),
        kind: group.kind,
        trial_ends_on: group.trial_ends_on,
        plan: be_a(String)
      }
    )
  end

  let(:existing_group_params) do
    group_params[:namespace].merge(kind: existing_group.kind, trial_ends_on: existing_group.trial_ends_on)
    group_params
  end

  let(:retry_params) { {} }

  let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
  let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }

  subject(:execute) { described_class.new(params: params, user: user, **retry_params).execute }

  describe '#execute' do
    context 'when successful' do
      it 'creates lead and applies trial successfully', :aggregate_failures do
        expect_create_lead_success(lead_params)
        expect_apply_trial_success(user, group, extra_params: group_params)

        expect { execute }.to change { Group.count }.by(1).and change { Project.count }.by(1)
        expect(execute).to be_success
        expect(execute.message).to eq('Trial applied')
        expect(execute.payload).to eq({ namespace_id: Group.last.id, add_on_purchase: add_on_purchase })
      end

      context 'when retrying' do
        before do
          allow(GitlabSubscriptions::Trials)
            .to receive(:namespace_eligible?).with(existing_group).and_return(true)
        end

        context "when project creation failed" do
          let(:retry_params) { { namespace_id: existing_group.id } }

          it 'uses existing group' do
            expect_create_lead_success(lead_params)
            expect_apply_trial_success(user, existing_group, extra_params: existing_group_params)

            expect { execute }.to not_change { Group.count }.and change { Project.count }.by(1)
            expect(execute).to be_success
            expect(execute.message).to eq('Trial applied')
            expect(execute.payload).to eq({ namespace_id: existing_group.id, add_on_purchase: add_on_purchase })
          end
        end

        context "when lead creation failed" do
          let(:retry_params) do
            { namespace_id: existing_group.id, project_id: existing_project.id, lead_created: false }
          end

          it 'uses existing group and project' do
            expect_create_lead_success(lead_params)
            expect_apply_trial_success(user, existing_group, extra_params: existing_group_params)

            expect { execute }.to not_change { Group.count }.and not_change { Project.count }
            expect(execute).to be_success
            expect(execute.message).to eq('Trial applied')
            expect(execute.payload).to eq({ namespace_id: existing_group.id, add_on_purchase: add_on_purchase })
          end
        end

        context "when trial creation failed" do
          let(:retry_params) do
            { namespace_id: existing_group.id, project_id: existing_project.id, lead_created: true }
          end

          it 'uses existing group, project and lead' do
            expect(lead_service_class).not_to receive(:new)
            expect_apply_trial_success(user, existing_group, extra_params: existing_group_params)

            expect { execute }.to not_change { Group.count }.and not_change { Project.count }
            expect(execute).to be_success
            expect(execute.message).to eq('Trial applied')
            expect(execute.payload).to eq({ namespace_id: existing_group.id, add_on_purchase: add_on_purchase })
          end
        end

        context "when project isn't owned by user" do
          let(:retry_params) do
            { namespace_id: existing_group.id, project_id: unrelated_project.id }
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end

        context "when namespace isn't owned by user" do
          let(:retry_params) do
            { namespace_id: unrelated_group.id }
          end

          before do
            allow(GitlabSubscriptions::Trials).to receive(:namespace_eligible?).with(unrelated_group).and_return(true)
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end

        context 'when namespace is not eligible for trial' do
          let(:retry_params) do
            { namespace_id: existing_group.id, project_id: existing_project.id, lead_created: true }
          end

          before do
            allow(GitlabSubscriptions::Trials)
              .to receive(:namespace_eligible?).with(existing_group).and_return(false)
          end

          it 'returns not found error and lead/trial is not submitted' do
            expect(lead_service_class).not_to receive(:new)
            expect(apply_trial_service_class).not_to receive(:new)

            expect(execute).to be_error
            expect(execute.message).to eq('Not found')
            expect(execute.reason).to eq(:not_found)
          end
        end
      end
    end

    context 'when namespace creation fails' do
      let(:params) { super().merge(group_name: '  ') }

      it 'returns model error and does not attempt to execute next steps' do
        expect(lead_service_class).not_to receive(:new)
        expect(apply_trial_service_class).not_to receive(:new)
        expect(Projects::CreateService).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.message).to eq("Trial creation failed in namespace stage")
        expect(execute.payload).to include({ namespace_id: nil, project_id: nil, lead_created: false })
        expect(execute.payload.dig(:model_errors, :group)).to include(/^Name can't be blank/)
      end
    end

    context 'when project creation fails' do
      let(:params) { super().merge(project_name: '  ') }

      it 'returns model error and does not attempt to execute next steps' do
        expect(lead_service_class).not_to receive(:new)
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.message).to eq("Trial creation failed in project stage")
        expect(execute.payload).to include({ namespace_id: Group.last.id, project_id: nil, lead_created: false })
        expect(execute.payload.dig(:model_errors, :project)).to include(/^Name can't be blank/)
      end
    end

    context 'when lead creation fails' do
      it 'returns error with lead failure reason and does not attempt to submit trial' do
        expect_create_lead_fail(lead_params)
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.message).to eq("Trial creation failed in lead stage")
        expect(execute.payload).to eq({ namespace_id: Group.last.id, project_id: Project.last.id, lead_created: false,
          model_errors: {} })
      end
    end

    context 'when trial creation fails' do
      it 'returns error with trial failure reason' do
        expect_create_lead_success(lead_params)
        expect_apply_trial_fail(user, group, extra_params: existing_group_params)

        expect(execute).to be_error
        expect(execute.message).to eq("Trial creation failed in application stage")
        expect(execute.payload).to eq({ namespace_id: Group.last.id, project_id: Project.last.id, lead_created: true,
          model_errors: {} })
      end
    end
  end
end
