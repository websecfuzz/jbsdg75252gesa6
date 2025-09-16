# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupDestroyWorker, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:admin) { create(:user, :admin, owner_of: group) }

  subject(:worker) { described_class.new }

  context 'with protective settings', :request_store do
    before do
      stub_ee_application_setting(
        default_project_deletion_protection: true
      )
    end

    where(:admin_mode_enabled, :user_is_admin, :should_delete) do
      true  | true   | true
      true  | false  | false
      false | true   | true
      false | false  | false
    end

    with_them do
      it do
        stub_application_setting(admin_mode: admin_mode_enabled)
        worker_user = user_is_admin ? admin : user

        if should_delete
          worker.perform(group.id, worker_user.id)
          expect(Group.all).not_to include(group)
          expect(Project.all).not_to include(project)
        else
          expect do
            worker.perform(group.id, worker_user.id)
          end.to raise_error(Groups::DestroyService::DestroyError)
        end
      end
    end
  end
end
