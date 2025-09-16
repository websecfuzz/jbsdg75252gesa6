# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembersHelper do
  include OncallHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(current_user)
  end

  describe '#project_members_app_data_json' do
    before do
      project.add_developer(current_user)
      create_schedule_with_user(project, current_user)
      allow(helper).to receive(:can?).and_return(true)
      allow(helper).to receive(:manage_member_roles_path).with(project)
        .and_return(admin_application_settings_roles_and_permissions_path)
    end

    it 'does not execute N+1' do
      control = ActiveRecord::QueryRecorder.new do
        call_project_members_app_data_json
      end

      expect(project.members.count).to eq(2)

      user_2 = create(:user)
      project.add_developer(user_2)
      create_schedule_with_user(project, user_2)

      expect(project.members.count).to eq(3)

      expect { call_project_members_app_data_json }.not_to exceed_query_limit(control).with_threshold(11) # existing n+1
    end

    it 'includes `manage_member_roles_path` data' do
      expect(Gitlab::Json.parse(call_project_members_app_data_json))
        .to include('manage_member_roles_path' => admin_application_settings_roles_and_permissions_path)
    end

    def call_project_members_app_data_json
      helper.project_members_app_data_json(
        project,
        members: preloaded_members,
        invited: [],
        access_requests: [],
        include_relations: [:inherited, :direct],
        search: nil,
        pending_members_count: nil
      )
    end

    # Simulates the behaviour in ProjectMembersController
    def preloaded_members
      klass = Class.new do
        include MembersPresentation

        def initialize(user)
          @current_user = user
        end

        attr_reader :current_user
      end

      klass.new(current_user).present_members(project.members.reload)
    end
  end

  describe '#project_members_app_data' do
    subject(:helper_app_data) do
      helper.project_members_app_data(
        project,
        members: [],
        invited: [],
        access_requests: [],
        include_relations: [:inherited, :direct],
        search: nil,
        pending_members_count: pending_members_count
      )
    end

    let(:pending_members_count) { nil }

    context 'with promotion_request feature' do
      let(:type) { :for_project_member }
      let(:member_namespace) { project.project_namespace }

      it_behaves_like 'adding promotion_request in app data'
    end

    context 'with `can_approve_access_requests`' do
      subject(:can_approve_access_requests) { helper_app_data[:can_approve_access_requests] }

      context 'when project has an associated group' do
        let_it_be(:project) { create(:project, group: create(:group)) }

        context 'when namespace has reached the user limit (can not approve accesss requests)' do
          before do
            stub_ee_application_setting(dashboard_limit_enabled: true)

            allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, project.root_ancestor) do |instance|
              allow(instance).to receive(:enforce_cap?).and_return(true)
            end
          end

          it 'sets the value to false' do
            stub_ee_application_setting(dashboard_limit: 0)

            expect(can_approve_access_requests).to eq(false)
          end
        end

        context 'when namespace has not reached the user limit (can approve access requests)' do
          it 'sets the value to true' do
            expect(can_approve_access_requests).to eq(true)
          end
        end
      end

      context 'when project is a personal project (no associated group)' do
        it 'sets the value to true' do
          expect(can_approve_access_requests).to eq(true)
        end
      end
    end

    context 'with `namespace_user_limit`' do
      subject(:namespace_user_limit) { helper_app_data[:namespace_user_limit] }

      context 'when dashboard limit is set' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)
        end

        it 'sets the value to false' do
          expect(namespace_user_limit).to eq(5)
        end
      end

      context 'when dashboard limit is not set' do
        it 'sets the value to false' do
          expect(namespace_user_limit).to eq(0)
        end
      end
    end

    describe 'available roles' do
      subject(:available_roles) { helper_app_data[:available_roles] }

      context 'when custom roles exist' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        let!(:member_role) { create(:member_role, :instance) }

        it { is_expected.to include(title: member_role.name, value: "custom-#{member_role.id}") }
      end
    end
  end

  describe '#project_member_header_subtext', feature_category: :groups_and_projects do
    let(:base_subtext) { "You can invite a new member to <strong>#{current_project.name}</strong> or invite another group." }
    let(:cannot_invite_subtext_for_com) { "You cannot invite a new member to <strong>#{current_project.name}</strong>. User invitations are disabled by the group owner." }
    let(:cannot_invite_subtext_for_self_managed) { "You cannot invite a new member to <strong>#{current_project.name}</strong>. User invitations are disabled by the instance administrator." }
    let(:standard_subtext) { "^#{base_subtext}$" }
    let(:enforcement_subtext) { "^#{base_subtext}<br />To manage seats for all members" }

    let_it_be(:project_with_group) { create(:project, group: create(:group)) }

    where(:com, :can_invite_member, :can_admin_member, :enforce_free_user_cap, :subtext, :current_project) do
      true | true | true | true | ref(:standard_subtext) | ref(:project)
      false | false | true | true | ref(:cannot_invite_subtext_for_self_managed) | ref(:project)
      true | false | true | true | ref(:cannot_invite_subtext_for_com) | ref(:project)

      true | true | true | true | ref(:enforcement_subtext) | ref(:project_with_group)
      false | false | true | true | ref(:cannot_invite_subtext_for_self_managed) | ref(:project_with_group)
      true | false | true | true | ref(:cannot_invite_subtext_for_com) | ref(:project_with_group)

      true | true | true | false | ref(:standard_subtext) | ref(:project_with_group)
      false | false | true | false | ref(:cannot_invite_subtext_for_self_managed) | ref(:project_with_group)
      true | false | true | false | ref(:cannot_invite_subtext_for_com) | ref(:project_with_group)

      true | true | false | true | ref(:standard_subtext) | ref(:project_with_group)
      false | false | false | true | ref(:cannot_invite_subtext_for_self_managed) | ref(:project_with_group)
      true | false | false | true  | ref(:cannot_invite_subtext_for_com) | ref(:project_with_group)

      true | true |  false | false | ref(:standard_subtext) | ref(:project_with_group)
      false | false | false | false | ref(:cannot_invite_subtext_for_self_managed) | ref(:project_with_group)
      true | false |  false | false | ref(:cannot_invite_subtext_for_com) | ref(:project_with_group)
    end

    before do
      assign(:project, current_project)

      allow(helper).to receive(:can?).with(current_user, :invite_project_members, current_project)
                                     .and_return(can_invite_member)
      allow(::Gitlab::Saas).to receive(:feature_available?).with(:group_disable_invite_members).and_return(com)

      if can_invite_member
        allow(helper).to receive(:can?).with(current_user, :admin_group_member, current_project.root_ancestor)
                                       .and_return(can_admin_member)
        allow(helper).to receive(:can?).with(current_user, :admin_project_member, current_project)
                                       .and_return(can_invite_member)
      end

      allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, current_project.root_ancestor) do |instance|
        allow(instance).to receive(:enforce_cap?).and_return(enforce_free_user_cap)
      end
    end

    with_them do
      it 'contains expected text' do
        expect(helper.project_member_header_subtext(current_project)).to match(subtext)
      end
    end
  end
end
