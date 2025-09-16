# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Projects::Commit, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:commit)  { project.commit }

  it { is_expected.to include_module(::Ai::Model) }

  describe '#resource_parent' do
    it 'returns the project' do
      expect(commit.resource_parent).to eq(project)
    end
  end
end
