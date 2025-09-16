# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ProjectsResolver, feature_category: :groups_and_projects do
  include GraphqlHelpers

  describe '#resolve' do
    subject { resolve(described_class, obj: nil, args: filters, ctx: { current_user: user }).items }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, developers: user) }
    let_it_be(:marked_for_deletion_on) { Date.yesterday }
    let_it_be(:hidden_project) { create(:project, :hidden, developers: user) }

    let_it_be(:project_marked_for_deletion) do
      create(:project, marked_for_deletion_at: marked_for_deletion_on, developers: user)
    end

    let(:filters) { {} }

    before do
      ::Current.organization = project.organization
    end

    context 'when includeHidden filter is true' do
      let(:filters) { { include_hidden: true } }

      it do
        is_expected.to contain_exactly(project, hidden_project, project_marked_for_deletion)
      end
    end

    context 'when includeHidden filter is false' do
      let(:filters) { { include_hidden: false } }

      it { is_expected.to contain_exactly(project, project_marked_for_deletion) }
    end
  end
end
