# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :product_planning do
    describe 'Epics roadmap' do
      include_context 'work item epics migration'
      include Support::Dates

      let(:group) { create(:group, name: "group-to-test-epic-roadmap-#{SecureRandom.hex(4)}") }
      let!(:epic) { create_epic_resource(group) }

      before do
        Flow::Login.sign_in
      end

      it 'presents epic on roadmap', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347992' do
        page.visit("#{group.web_url}/-/roadmap")

        EE::Page::Group::Roadmap.perform do |roadmap|
          expect(roadmap).to have_epic(epic)
        end
      end

      def create_epic_resource(group)
        begin
          epic = create(:work_item_epic,
            group: group,
            title: 'Work Item Epic created via API to test roadmap',
            is_fixed: true,
            start_date: current_date_yyyy_mm_dd_iso,
            due_date: next_month_yyyy_mm_dd_iso)
        rescue ArgumentError, NotImplementedError
          epic = create(:epic,
            group: group,
            title: 'Epic created via API to test roadmap',
            start_date_is_fixed: true,
            start_date_fixed: current_date_yyyy_mm_dd,
            due_date_is_fixed: true,
            due_date_fixed: next_month_yyyy_mm_dd)
        else
          update_web_url(group, epic)
        end
        epic
      end
    end
  end
end
