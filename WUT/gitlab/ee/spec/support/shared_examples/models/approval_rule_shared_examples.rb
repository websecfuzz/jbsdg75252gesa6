# frozen_string_literal: true

RSpec.shared_examples '#editable_by_user?' do
  subject(:editable) { approval_rule.editable_by_user?(user) }

  let(:user) { merge_request.author }

  RSpec.shared_examples 'not editable by user' do
    it 'is not editable by user' do
      expect(editable).to be_falsey
    end
  end

  RSpec.shared_examples 'editable by user' do
    it 'is editable by user' do
      expect(editable).to be_truthy
    end
  end

  context 'when rule is user defined' do
    let(:user) { merge_request.author }
    let(:approval_rule) { any_approver_rule }

    context 'when the user can admin resources but otherwise not allowed' do
      let(:user) { create(:user) }

      before do
        allow(user).to receive(:can_admin_all_resources?).and_return(true)
      end

      it_behaves_like 'editable by user'
    end

    context 'when user is set' do
      context 'when project can override approvers' do
        let(:project) { create(:project, :public, disable_overriding_approvers_per_merge_request: false) }

        context 'when the merge request can be updated' do
          context 'when the user is the assignee or author' do
            context 'when the user is a project member' do
              before do
                project.add_developer(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the project has public merge request access level' do
              let(:project) { create(:project, :merge_requests_public) }

              it_behaves_like 'editable by user'
            end

            context 'when user is not a project member' do
              before do
                merge_request.update!(author: create(:user))
              end

              context 'when the project only allows project members access' do
                let(:project) { create(:project, :merge_requests_private) }

                it_behaves_like 'not editable by user'
              end
            end
          end

          context 'when user is not the author or assignee' do
            let(:user) { create(:user) }

            context 'when the user is a maintainer' do
              before do
                project.add_maintainer(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the user is a owner' do
              before do
                project.add_owner(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the user is a developer' do
              before do
                project.add_developer(user)
              end

              it_behaves_like 'not editable by user'
            end
          end
        end

        context 'when the merge request can not be updated' do
          let(:user) { create(:user) }

          it_behaves_like 'not editable by user' do
            before do
              # Need to ensure MR is created before turning off the merge requests for the project
              merge_request
              project.project_feature.merge_requests_access_level = Featurable::DISABLED
              project.save!
            end
          end
        end
      end

      context 'when project can not override approvers' do
        let(:project) { create(:project, disable_overriding_approvers_per_merge_request: true) }

        it_behaves_like 'not editable by user'
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it_behaves_like 'not editable by user'
    end
  end

  context 'when rule is not user defined' do
    let(:user) { merge_request.author }
    let(:approval_rule) { code_owner_rule }

    it_behaves_like 'not editable by user'
  end
end
