# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::AllBranchesRulePolicy, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:branch_rule) { Projects::AllBranchesRule.new(project) }

  subject { described_class.new(user, branch_rule) }

  context 'as a maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    it_behaves_like 'allows branch rule crud'
  end

  context 'as a developer' do
    before_all do
      project.add_developer(user)
    end

    it_behaves_like 'disallows branch rule crud'
  end

  context 'as a guest' do
    before_all do
      project.add_guest(user)
    end

    it_behaves_like 'disallows branch rule crud'
  end
end
