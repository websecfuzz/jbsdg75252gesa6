# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::BranchRules::SquashOptions::DestroyService, feature_category: :source_code_management do
  describe '#execute' do
    let_it_be(:protected_branch) { create :protected_branch }
    let_it_be(:project) { protected_branch.project }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }

    let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
    let(:current_user) { maintainer }

    subject(:execute) { described_class.new(branch_rule, current_user: current_user).execute }

    context 'when there is a squash option' do
      let!(:squash_option) { create :branch_rule_squash_option, project: project, protected_branch: protected_branch }

      context 'and the user is not authorized' do
        let(:current_user) { developer }

        it 'returns an error response' do
          result = execute

          expect(result.message).to eq(described_class::AUTHORIZATION_ERROR_MESSAGE)
          expect(result).to be_error
        end
      end

      it 'deletes the squash option' do
        expect { execute }
          .to change { ::Projects::BranchRules::SquashOption.count }.from(1).to(0)

        expect(execute).to be_success
      end
    end

    it 'returns an error' do
      result = execute

      expect(result.message).to eq(described_class::AUTHORIZATION_ERROR_MESSAGE)
      expect(result).to be_error
    end
  end
end
