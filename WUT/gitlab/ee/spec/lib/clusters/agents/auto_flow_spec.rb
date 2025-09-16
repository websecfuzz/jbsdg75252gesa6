# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agents::AutoFlow, feature_category: :deployment_management do
  describe '#issue_events_enabled?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:work_item) { create(:work_item, :issue) }

    where(:kas_enabled, :autoflow_enabled, :autoflow_issue_events_enabled, :expected) do
      true  | true  | true  | true
      true  | true  | false | false
      true  | false | true  | false
      true  | false | false | false
      false | true  | true  | false
      false | true  | false | false
      false | false | true  | false
      false | false | false | false
    end

    with_them do
      it 'returns the correct boolean value based on KAS configuration and feature flags' do
        allow(Gitlab::Kas).to receive(:enabled?).and_return(kas_enabled)
        stub_feature_flags(
          autoflow_enabled: autoflow_enabled,
          autoflow_issue_events_enabled: autoflow_issue_events_enabled
        )

        expect(described_class.issue_events_enabled?(work_item.id)).to be(expected)
      end
    end

    context 'when work item is not an issue' do
      let_it_be(:work_item) { create(:work_item, :epic) }

      it 'returns false' do
        expect(described_class.issue_events_enabled?(work_item.id)).to be(false)
      end
    end

    context 'when work item does not exist' do
      it 'returns false' do
        expect(described_class.issue_events_enabled?(non_existing_record_id)).to be(false)
      end
    end
  end

  describe '#merge_request_events_enabled?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:merge_request) { create(:merge_request) }

    where(:kas_enabled, :autoflow_enabled, :autoflow_merge_request_events_enabled, :expected) do
      true  | true  | true  | true
      true  | true  | false | false
      true  | false | true  | false
      true  | false | false | false
      false | true  | true  | false
      false | true  | false | false
      false | false | true  | false
      false | false | false | false
    end

    with_them do
      it 'returns the correct boolean value based on KAS configuration and feature flags' do
        allow(Gitlab::Kas).to receive(:enabled?).and_return(kas_enabled)
        stub_feature_flags(
          autoflow_enabled: autoflow_enabled,
          autoflow_merge_request_events_enabled: autoflow_merge_request_events_enabled
        )

        expect(described_class.merge_request_events_enabled?(merge_request.id)).to be(expected)
      end
    end

    context 'when merge request does not exist' do
      it 'returns false' do
        expect(described_class.merge_request_events_enabled?(non_existing_record_id)).to be(false)
      end
    end
  end
end
