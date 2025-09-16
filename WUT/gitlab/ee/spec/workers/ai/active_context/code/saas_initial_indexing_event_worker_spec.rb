# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::SaasInitialIndexingEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::SaasInitialIndexingEvent.new(data: {}) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, adapter_class: ActiveContext::Databases::Elasticsearch::Adapter)
  end

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  before do
    stub_const("#{described_class}::NAMESPACE_IDS", [namespace.id])
    allow(::Gitlab::Saas).to receive(:feature_available?).and_return(true)
  end

  context 'for eligibility conditions', :saas do
    using RSpec::Parameterized::TableSyntax

    where(:scenario_name, :indexing_enabled, :duo_chat_available,
      :subscription_status, :add_on_status, :subscription_namespace_match,
      :namespace_in_allowlist, :duo_features_enabled, :experiment_features_enabled, :has_parent, :expected_outcome) do
      # Happy path - all conditions satisfied
      'all conditions satisfied'     | true  | true  | :valid | :active | true  | true  | true  | true  | false | true

      # Basic prerequisite checks
      'indexing disabled'            | false | true  | :valid | :active | true  | true  | true  | true  | false | false
      'duo chat not available'       | true  | false | :valid | :active | true  | true  | true  | true  | false | false

      # Subscription-related conditions
      'subscription expired'         | true  | true  | :exp   | :active | true  | true  | true  | true  | false | false
      'free subscription'            | true  | true  | :free  | :active | true  | true  | true  | true  | false | false
      'no subscription'              | true  | true  | :none  | :active | true  | true  | true  | true  | false | false
      'subscription on other ns'     | true  | true  | :valid | :active | false | true  | true  | true  | false | false

      # Add-on related conditions
      'add-on trial'                 | true  | true  | :valid | :trial | true | true | true | true | false | false
      'no add-on'                    | true  | true  | :valid | :none  | true | true | true | true | false | false

      # Namespace-related conditions
      'namespace not in allowlist'   | true  | true  | :valid | :active | true  | false | true  | true  | false | false
      'duo features disabled'        | true  | true  | :valid | :active | true  | true  | false | true  | false | false
      'experiment features disabled' | true  | true  | :valid | :active | true  | true  | true  | false | false | false
      'namespace has parent'         | true  | true  | :valid | :active | true  | true  | true  | true  | true  | false

      # Record already exists
      'record already exists'        | true  | true  | :valid | :active | true  | true  | true  | true  | false | false
    end

    with_them do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(indexing_enabled)
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:duo_chat_on_saas).and_return(duo_chat_available)

        other_namespace_id = namespace.id + 1
        stub_const("#{described_class}::NAMESPACE_IDS", [other_namespace_id]) unless namespace_in_allowlist

        case add_on_status
        when :active
          create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace)
        when :trial
          create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: namespace)
        end

        subscription_namespace = subscription_namespace_match ? namespace : create(:group)
        case subscription_status
        when :valid
          create(:gitlab_subscription, namespace: subscription_namespace)
        when :exp
          create(:gitlab_subscription, :expired, namespace: subscription_namespace)
        when :free
          create(:gitlab_subscription, :free, namespace: subscription_namespace)
        end

        if scenario_name == 'record already exists'
          create(:ai_active_context_code_enabled_namespace, namespace: namespace, active_context_connection: connection)
        end

        namespace.namespace_settings.update_columns(
          duo_features_enabled: duo_features_enabled,
          experiment_features_enabled: experiment_features_enabled
        )
      end

      around do |example|
        namespace.update!(parent: create(:group)) if has_parent

        example.run

        namespace.update!(parent: nil) if namespace.parent
      end

      it 'behaves as expected' do
        if expected_outcome
          expect(Ai::ActiveContext::Code::EnabledNamespace).to receive(:insert_all).with(
            [{ namespace_id: namespace.id, connection_id: connection.id }],
            { unique_by: %w[connection_id namespace_id] }
          )
        else
          expect(Ai::ActiveContext::Code::EnabledNamespace).not_to receive(:insert_all)
        end

        execute
      end
    end
  end
end
