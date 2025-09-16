# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::DestroyService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let!(:agent) { create(:ai_catalog_item, :with_version, project: project) }

  let(:params) { { agent: agent } }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    shared_examples 'returns agent not found error' do
      it 'returns agent not found error' do
        result = execute_service

        expect(result).to be_error
        expect(result.errors).to contain_exactly('Agent not found')
      end

      it 'does not destroy any agents' do
        expect { execute_service }.not_to change { Ai::Catalog::Item.count }
      end
    end

    context 'when agent is invalid' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when agent is nil' do
        let(:params) { { agent: nil } }

        it_behaves_like 'returns agent not found error'
      end

      context 'when catalog item is not an agent' do
        before do
          allow(agent).to receive(:item_type).and_return('flow')
        end

        it_behaves_like 'returns agent not found error'
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when agent exists' do
        it 'destroys the agent successfully' do
          expect { execute_service }.to change { Ai::Catalog::Item.count }.by(-1)
        end

        it 'destroys agent versions' do
          expect { execute_service }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
        end

        it 'returns success response' do
          result = execute_service

          expect(result.success?).to be(true)
        end
      end

      context 'when agent destruction fails' do
        before do
          allow(agent).to receive(:destroy).and_return(false)
          agent.errors.add(:base, 'Agent cannot be destroyed')
        end

        it 'does not destroy the agent' do
          expect { execute_service }.not_to change { Ai::Catalog::Item.count }
        end

        it 'returns error response' do
          result = execute_service

          expect(result).to be_error
          expect(result.errors).to contain_exactly('Agent cannot be destroyed')
        end
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it 'returns permission error' do
        result = execute_service

        expect(result).to be_error
        expect(result.errors).to contain_exactly('You have insufficient permissions')
      end

      it 'does not destroy the agent' do
        expect { execute_service }.not_to change { Ai::Catalog::Item.count }
      end
    end
  end
end
