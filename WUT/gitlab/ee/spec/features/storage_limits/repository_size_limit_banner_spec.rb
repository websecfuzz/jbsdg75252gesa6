# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Repository size limit banner", :js, :saas, feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers

  let_it_be(:owner) { create(:user, namespace: create(:user_namespace)) }
  let_it_be(:free_group) { create(:group, owners: owner) }
  let_it_be_with_refind(:free_group_project) { create(:project, :repository, group: free_group) }
  let_it_be(:paid_group) { create(:group_with_plan, plan: :ultimate_plan, owners: owner) }
  let_it_be_with_refind(:paid_group_project) { create(:project, :repository, group: paid_group) }

  before do
    sign_in(owner)
    stub_ee_application_setting(automatic_purchased_storage_allocation: true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_ee_application_setting(repository_size_limit: 10.megabytes)
  end

  context 'when namespace storage limits are disabled' do
    before do
      stub_ee_application_setting(enforce_namespace_storage_limit: false)
      stub_feature_flags(namespace_storage_limit: false)
    end

    it 'shows the banner when a project repository in a free group has exceed the storage limit' do
      free_group_project.statistics.update!(repository_size: 11.megabytes)

      visit(project_path(free_group_project))

      expect(page).to have_text("You have reached the free storage limit of 10 MiB on 1 project")
    end

    it 'shows the banner when a project repository in a paid group has exceed the storage limit' do
      paid_group_project.statistics.update!(repository_size: 11.megabytes)

      visit(project_path(paid_group_project))

      expect(page).to have_text("#{paid_group.name} has 1 read-only project")
    end
  end

  context 'when namespace storage limits are enabled for free plans' do
    before do
      enforce_namespace_storage_limit(free_group)
    end

    it 'shows the banner when a project repository in a paid group has exceed the storage limit' do
      paid_group_project.statistics.update!(repository_size: 11.megabytes)

      visit(project_path(paid_group_project))

      expect(page).to have_text("#{paid_group.name} has 1 read-only project")
    end
  end
end
