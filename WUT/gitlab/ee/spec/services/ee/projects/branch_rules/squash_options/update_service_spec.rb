# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::BranchRules::SquashOptions::UpdateService, feature_category: :source_code_management do
  describe 'ee #execute added through extension' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let(:squash_option) { ::Projects::BranchRules::SquashOption.squash_options['always'] }

    subject(:execute) do
      described_class.new(branch_rule, squash_option: squash_option, current_user: current_user).execute
    end

    context 'when branch rule is BranchRule' do
      let_it_be(:protected_branch) { create :protected_branch, project: project }
      let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
      let(:current_user) { maintainer }

      context 'and the feature is available' do
        before do
          stub_licensed_features(branch_rule_squash_options: true)
        end

        context 'when there is a squash option' do
          let!(:existing_squash_option) do
            create :branch_rule_squash_option, project: project, protected_branch: protected_branch
          end

          it 'updates the squash option' do
            expect { execute }
              .to change { protected_branch.squash_option.squash_option }.from('default_off').to('always')
              .and not_change { ::Projects::BranchRules::SquashOption.count }.from(1)

            expect(execute).to be_success
          end
        end

        it 'creates a squash option' do
          expect { execute }
            .to change { protected_branch&.squash_option&.squash_option }.from(nil).to('always')
            .and change { ::Projects::BranchRules::SquashOption.count }.from(0).to(1)

          expect(execute).to be_success
        end
      end
    end
  end
end
