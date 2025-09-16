# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Audit events', :js, feature_category: :audit_events do
  include Features::MembersHelpers
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:alex) { create(:user, name: 'Alex') }
  let_it_be_with_reload(:group) { create(:group) }

  before do
    group.add_owner(user)
    group.add_developer(alex)
    stub_feature_flags(show_role_details_in_drawer: false)
    sign_in(user)
  end

  context 'unlicensed' do
    before do
      stub_licensed_features(audit_events: false)
    end

    it 'returns 404' do
      reqs = inspect_requests do
        visit group_audit_events_path(group)
      end

      expect(reqs.first.status_code).to eq(404)
    end

    it 'does not have Audit events button in head nav bar' do
      visit group_security_dashboard_path(group)

      expect(page).not_to have_link('Audit events')
    end
  end

  it 'has Audit events button in head nav bar' do
    visit group_audit_events_path(group)

    expect(page).to have_link('Audit events')
  end

  describe 'changing a user access level' do
    it "appears in the group's audit events" do
      visit group_group_members_path(group)

      wait_for_requests

      page.within first_row do
        select_from_listbox 'Maintainer', from: 'Developer'
      end

      within_testid('super-sidebar') do
        click_button 'Secure'
        click_link 'Audit events'
      end

      page.within('.audit-log-table') do
        expect(page).to have_content 'Changed access level from Default role: Developer to Default role: Maintainer'
        expect(page).to have_content(user.name)
        expect(page).to have_content('Alex')
      end
    end
  end

  describe 'audit event filter' do
    let_it_be(:events_path) { :group_audit_events_path }
    let_it_be(:entity) { group }

    describe 'filter by date' do
      let_it_be(:old_audit_event_1) { create(:group_audit_event, entity_type: 'Group', entity_id: group.id, created_at: 5.days.ago) }
      let_it_be(:old_audit_event_2) { create(:group_audit_event, entity_type: 'Group', entity_id: group.id, created_at: 3.days.ago) }
      let_it_be(:old_audit_event_3) { create(:group_audit_event, entity_type: 'Group', entity_id: group.id, created_at: Date.current) }

      let_it_be(:new_audit_event_1) { create(:audit_events_group_audit_event, group_id: group.id, created_at: 5.days.ago) }
      let_it_be(:new_audit_event_2) { create(:audit_events_group_audit_event, group_id: group.id, created_at: 3.days.ago) }
      let_it_be(:new_audit_event_3) { create(:audit_events_group_audit_event, group_id: group.id, created_at: Date.current) }

      context 'when read_audit_events_from_new_tables is disabled' do
        before do
          stub_feature_flags(read_audit_events_from_new_tables: false)
        end

        it_behaves_like 'audit events date filter' do
          let(:audit_event_1) { old_audit_event_1 }
          let(:audit_event_2) { old_audit_event_2 }
          let(:audit_event_3) { old_audit_event_3 }
        end
      end

      context 'when read_audit_events_from_new_tables is enabled' do
        before do
          stub_feature_flags(read_audit_events_from_new_tables: true)
        end

        it_behaves_like 'audit events date filter' do
          let(:audit_event_1) { new_audit_event_1 }
          let(:audit_event_2) { new_audit_event_2 }
          let(:audit_event_3) { new_audit_event_3 }
        end
      end
    end

    context 'signed in as a developer' do
      before do
        sign_in(alex)
      end

      describe 'filter by author' do
        let_it_be(:old_audit_event_1) { create(:group_audit_event, entity_type: 'Group', entity_id: group.id, created_at: Date.today, ip_address: '1.1.1.1', author_id: alex.id) }
        let_it_be(:old_audit_event_2) { create(:group_audit_event, entity_type: 'Group', entity_id: group.id, created_at: Date.today, ip_address: '0.0.0.0', author_id: user.id) }

        let_it_be(:new_audit_event_1) { create(:audit_events_group_audit_event, group_id: group.id, created_at: Date.today, ip_address: '1.1.1.1', author_id: alex.id) }
        let_it_be(:new_audit_event_2) { create(:audit_events_group_audit_event, group_id: group.id, created_at: Date.today, ip_address: '0.0.0.0', author_id: user.id) }

        let_it_be(:author) { user }

        context 'when read_audit_events_from_new_tables is disabled' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: false)
          end

          it_behaves_like 'audit events author filtering without entity admin permission' do
            let(:audit_event_1) { old_audit_event_1 }
            let(:audit_event_2) { old_audit_event_2 }
          end
        end

        context 'when read_audit_events_from_new_tables is enabled' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: true)
          end

          it_behaves_like 'audit events author filtering without entity admin permission' do
            let(:audit_event_1) { new_audit_event_1 }
            let(:audit_event_2) { new_audit_event_2 }
          end
        end
      end
    end
  end
end
