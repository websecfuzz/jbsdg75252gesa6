# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Codeowners' do
      context 'when the project is in the root group', :requires_admin, product_group: :source_code do
        let(:approver) { create(:user, api_client: Runtime::API::Client.as_admin) }

        let(:root_group) { create(:sandbox) }
        let(:project) { create(:project, :with_readme, name: 'code-owner-approve-and-merge', group: root_group) }

        before do
          group_or_project.add_member(approver, Resource::Members::AccessLevel::MAINTAINER)

          Flow::Login.sign_in

          project.visit!
        end

        context 'and the code owner is the root group', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347804' do
          let(:codeowner) { root_group.path }
          let(:group_or_project) { root_group }

          it_behaves_like 'code owner merge request'
        end

        context 'and the code owner is a user', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347805' do
          let(:codeowner) { approver.username }
          let(:group_or_project) { project }

          it_behaves_like 'code owner merge request'
        end
      end
    end
  end
end
