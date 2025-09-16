# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::Setup, :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  include RakeHelpers

  let!(:group) { create(:group, :with_organization, path: 'gitlab-duo') }
  let!(:project) { create(:project, group: group) }
  let!(:user) { create(:user, maintainer_of: project, username: 'root') }

  let(:task) { described_class.new(args) }

  let(:feature_flags) do
    [
      :enable_hamilton_in_user_preferences,
      :allow_organization_creation
    ]
  end

  before_all do
    Rake.application.rake_require 'tasks/seed_fu'
    Rake::Task.define_task(:environment)
  end

  subject(:setup) { task.execute }

  before do
    feature_flags.each { |flag| ::Feature.disable(flag) }
    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
  end

  shared_examples 'checks for dev or test env' do
    context 'with production environment' do
      before do
        allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
      end

      it 'raises an error' do
        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'enables all necessary feature flags' do
    it 'enables all necessary feature flags', :aggregate_failures do
      setup

      feature_flags.each do |flag|
        expect(::Feature.enabled?(flag)).to be_truthy # rubocop:disable Gitlab/FeatureFlagWithoutActor -- For dev
      end
    end
  end

  shared_examples 'errors when there is no license' do
    context 'when there is no license' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'creates add-on purchases' do
    it 'creates enterprise add-on purchases', :aggregate_failures do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(0)
      expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(1)
    end
  end

  context 'when simulating GitLabCom', :saas do
    let(:args) { {} }

    before do
      stub_env('GITLAB_SIMULATE_SAAS', '1')

      original_paths = SeedFu.fixture_paths
      allow(SeedFu).to receive(:fixture_paths).and_return(
        original_paths + ['ee/db/fixtures/development']
      )

      stub_env('SEED_GITLAB_DUO', '1')
      allow(SeedFu).to receive(:seed).and_call_original
    end

    context 'when group does not exist' do
      before do
        group.destroy!
      end

      it 'creates a new group and adds user to group' do
        expect { setup }.to change { ::Group.count }.by(1)
        expect(Group.find_by_path('gitlab-duo').reload.users).to include(user)
      end
    end

    context 'when group already exists' do
      it 'does not create a new group' do
        expect { setup }.not_to change { ::Group.count }
      end
    end

    context 'when creating duo pro add on' do
      let(:args) { { add_on: 'duo_pro' } }

      it 'creates duo pro add-on only' do
        setup

        expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(1)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(0)
      end
    end

    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'

    it 'creates add on purchases for the right group, and not for the entire instance' do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(group).count).to eq(2)
      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(nil).count).to eq(0)
    end

    it 'adds an ultimate license with 100 seats' do
      setup

      subscription = ::GitlabSubscription.find_by(namespace: group)

      expect(subscription).to be_present
      expect(subscription.hosted_plan.name).to eq('ultimate')
      expect(subscription.seats).to eq(100)
    end

    context 'when updating application setting' do
      it 'changes application settings' do
        expect { setup }.to change {
                              Gitlab::CurrentSettings.current_application_settings.check_namespace_plan
                            }.to(true)
         .and change {
                Gitlab::CurrentSettings.current_application_settings
                                              .allow_local_requests_from_web_hooks_and_services
              }.to(true)
      end
    end
  end

  context 'when simulating SelfManaged: applying for entire instance' do
    before do
      allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

      stub_env('GITLAB_SIMULATE_SAAS', '0')
    end

    let(:rake_task) { instance_double(Rake::Task, invoke: true) }

    let(:args) { {} }

    context 'when License does not exist' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end

    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'

    it 'sets up add on purchases for the entire instance, and not for a specific group' do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(nil).count).to eq(2)
      expect(::GitlabSubscriptions::AddOnPurchase.by_namespace(group).count).to eq(0)
    end
  end

  context 'when seeding Gitlab Duo data' do
    let(:rake_task) { instance_double(Rake::Task, :seed_fu) }

    before do
      allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)
      allow(rake_task).to receive(:invoke)
      allow($stdout).to receive(:puts)
    end

    context 'when Gitlab Duo data is not seeded' do
      it 'prints a message indicating seeding is happening' do
        expect($stdout).to receive(:puts).with('Seeding GitLab Duo data...')

        ::Gitlab::Duo::Developments.seed_data(nil)
      end

      it 'invokes the db:seed_fu rake task' do
        ::Gitlab::Duo::Developments.seed_data(nil)

        expect(rake_task).to have_received(:invoke)
      end
    end

    context 'when Gitlab Duo data is already seeded' do
      before do
        allow(Group).to receive(:find_by_full_path).with(nil).and_return(group)
      end

      let(:expected_already_seeded_message) do
        <<~TXT.strip
          ================================================================================
          ## Gitlab Duo test group and project already seeded
          ## If you want to destroy and re-create them, you can re-run the seed task
          ## SEED_GITLAB_DUO=1 FILTER=gitlab_duo bundle exec rake db:seed_fu
          ## See https://docs.gitlab.com/development/ai_features/testing_and_validation/#seed-project-and-group-resources-for-testing-and-evaluation
          ================================================================================
        TXT
      end

      it 'prints a message indicating data is already seeded' do
        expect($stdout).to receive(:puts).with(expected_already_seeded_message)

        ::Gitlab::Duo::Developments.seed_data(nil)
      end

      it 'does not invoke the db:seed_fu rake task' do
        ::Gitlab::Duo::Developments.seed_data(nil)

        expect(rake_task).not_to have_received(:invoke)
      end
    end
  end
end
