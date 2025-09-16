# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::NamespaceLimit::ProjectPreEnforcementAlertComponent, :saas, type: :component,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers

  let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
  let_it_be_with_refind(:user) { create(:user) }

  subject(:component) { described_class.new(context: project, user: user) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true, automatic_purchased_storage_allocation: true)
    set_dashboard_limit(group, megabytes: 5_120, enabled: false)
    set_notification_limit(group, megabytes: 500)

    project.add_guest(user)
  end

  shared_examples 'dismissible alert' do
    context 'when the user dismissed the alert under 14 days ago', :freeze_time do
      before do
        create_callout_for_context(dismissed_at: 1.day.ago, user: user, context: context)
      end

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_text "A namespace storage limit of 5 GiB  will soon be enforced"
      end
    end

    context 'when the user dismissed the alert over 14 days ago', :freeze_time do
      before do
        create_callout_for_context(dismissed_at: 14.days.ago, user: user, context: context)
      end

      it 'does render the alert' do
        render_inline(component)

        expect(page).to have_text "A namespace storage limit of 5 GiB will soon be enforced"
      end
    end

    def create_callout_for_context(dismissed_at:, user:, context:)
      context_name = context.class.name.downcase

      create(
        context_name == 'project' ? :project_callout : :group_callout,
        {
          user: user,
          feature_name: 'namespace_storage_pre_enforcement_banner',
          dismissed_at: dismissed_at
        }.merge(context_name => context)
      )
    end
  end

  context 'with project in a group' do
    let_it_be_with_refind(:project) { create(:project, group: group) }
    let(:context) { group }

    before do
      group.root_storage_statistics.update!(
        storage_size: 5.gigabytes
      )
    end

    it 'includes the correct project info in the alert text' do
      render_inline(component)

      expect(page).to have_text "The #{project.name} project will be affected by this."

      expect(page).to have_css("[data-dismiss-endpoint='#{group_callouts_path}']")
      expect(page).to have_css("[data-group-id='#{group.root_ancestor.id}']")
    end

    it_behaves_like 'dismissible alert'
  end

  context 'with project belonging to user' do
    let_it_be_with_refind(:project) { create(:project) }
    let(:context) { project }

    before do
      storage = instance_double(
        Namespace::RootStorageStatistics,
        storage_size: 5.gigabytes,
        cost_factored_storage_size: 5.gigabytes,
        public_forks_storage_size: 0,
        internal_forks_storage_size: 0,
        cache_key_with_version: 'namespace/root_storage_statistics/01-20230601080953661909'
      )

      allow(project.root_ancestor)
        .to receive(:root_storage_statistics)
        .and_return(storage)
    end

    it 'includes the correct project info in the alert text' do
      render_inline(component)

      expect(page).to have_text "The #{project.name} project will be affected by this."

      expect(page).to have_css("[data-dismiss-endpoint='#{project_callouts_path}']")
      expect(page).to have_css("[data-project-id='#{project.id}']")
    end

    it_behaves_like 'dismissible alert'
  end
end
