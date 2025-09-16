# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembersController, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project, reload: true) { create(:project, :public) }
  let(:requester) { create(:project_member, :guest, project: project) }
  let(:requester2) { create(:project_member, :guest, project: project) }

  let(:params) do
    {
      project_member: { access_level: Gitlab::Access::MAINTAINER },
      namespace_id: project.namespace,
      project_id: project,
      id: requester
    }
  end

  describe 'PUT update' do
    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    include_examples 'member promotion management'
  end
end
