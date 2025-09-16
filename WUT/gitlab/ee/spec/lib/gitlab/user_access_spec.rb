# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UserAccess do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }
  let(:access) { described_class.new(user, container: project) }

  describe '#can_push_to_branch?' do
    describe 'push to empty project' do
      let(:project) { create(:project_empty_repo) }

      it 'returns false when the external service denies access' do
        project.add_maintainer(user)
        external_service_deny_access(user, project)

        expect(access.can_push_to_branch?('master')).to be_falsey
      end
    end
  end
end
