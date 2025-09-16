# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::BaseService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }

  subject(:service) { described_class.new(branch_rule, user) }

  describe '#action_name' do
    it 'raises a missing method error' do
      expect { service.send(:action_name) }
        .to raise_error(BranchRules::BaseService::MISSING_METHOD_ERROR, /Please define an `action_name` method/)
    end
  end
end
