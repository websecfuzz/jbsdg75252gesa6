# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CodeSuggestionEvent, feature_category: :code_suggestions do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'code_suggestion_shown_in_ide' } }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }

  it { is_expected.to belong_to(:organization) }

  it_behaves_like 'common ai_usage_event'

  describe '.payload_attributes' do
    it 'has list of payload attributes' do
      expect(described_class.payload_attributes).to match_array(
        %w[language suggestion_size unique_tracking_id branch_name]
      )
    end
  end

  describe '.for' do
    let_it_be(:group) { create(:group, :with_organization) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project_1) { create(:project, group: group) }
    let_it_be(:project_2) { create(:project, group: sub_group) }
    let_it_be(:event_1) do
      create(:ai_code_suggestion_event, organization: group.organization,
        namespace_path: project_1.reload.project_namespace.traversal_path)
    end

    let_it_be(:event_2) do
      create(:ai_code_suggestion_event, organization: group.organization,
        namespace_path: project_2.reload.project_namespace.traversal_path)
    end

    let(:resource) { group }

    subject(:get_events) { described_class.for(resource) }

    it 'filters records using IN operator optimization' do
      expect_next_instance_of(Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder) do |builder|
        expect(builder).to receive(:execute)
      end

      get_events
    end

    context 'when resource is a group' do
      it { is_expected.to contain_exactly(event_1, event_2) }
    end

    context 'when resource is a project' do
      let(:resource) { project_2 }

      it { is_expected.to contain_exactly(event_2) }
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:organization_id) }
  end

  describe '#organization_id' do
    subject { described_class.new(user: user) }

    it { is_expected.to populate_sharding_key(:organization_id).with(organization.id) }
  end

  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:attributes) do
      super().merge(
        user: user,
        timestamp: 1.day.ago,
        payload: {
          suggestion_size: 3,
          language: 'foo',
          unique_tracking_id: 'bar',
          branch_name: 'main'
        }
      )
    end

    it 'returns serialized attributes hash' do
      expect(event.to_clickhouse_csv_row).to eq({
        user_id: user.id,
        event: described_class.events[:code_suggestion_shown_in_ide],
        timestamp: 1.day.ago.to_f,
        suggestion_size: 3,
        language: 'foo',
        unique_tracking_id: 'bar',
        branch_name: 'main',
        namespace_path: nil
      })
    end
  end

  describe '#store_to_pg', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(Ai::UsageEventWriteBuffer).not_to receive(:add)

        event.store_to_pg
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(
          user: user,
          timestamp: 1.day.ago,
          payload: {
            suggestion_size: 3,
            language: 'foo',
            unique_tracking_id: 'bar'
          }
        )
      end

      it 'adds model attributes to write buffer' do
        expect(Ai::UsageEventWriteBuffer).to receive(:add)
          .with('Ai::CodeSuggestionEvent', {
            event: 'code_suggestion_shown_in_ide',
            timestamp: 1.day.ago,
            user_id: user.id,
            organization_id: organization.id,
            payload: {
              suggestion_size: 3,
              language: 'foo',
              unique_tracking_id: 'bar'
            }
          }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end
end
