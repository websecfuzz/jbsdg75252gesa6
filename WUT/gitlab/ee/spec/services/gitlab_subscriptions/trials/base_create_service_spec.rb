# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::BaseCreateService, feature_category: :subscription_management do
  let_it_be(:group) { create(:group) }

  let(:step) { 'lead' }
  let(:create_params) do
    {
      step: step,
      lead_params: {},
      trial_params: { namespace_id: group.id },
      user: build(:user)
    }
  end

  shared_examples 'raises NoMethodError' do |message|
    it do
      expect { execute }.to raise_error(NoMethodError, message)
    end
  end

  subject(:execute) { test_class.new(**create_params).execute }

  context 'when lead_service_class is not implemented' do
    let(:test_class) { described_class }

    it_behaves_like 'raises NoMethodError', 'Subclasses must implement the lead_service_class method'
  end

  context 'when namespaces_eligible_for_trial is not implemented' do
    let(:test_class) do
      Class.new(described_class) do
        def lead_service_class
          GitlabSubscriptions::CreateLeadService
        end

        def tracking_prefix
          ''
        end
      end
    end

    before do
      allow_next_instance_of(GitlabSubscriptions::CreateLeadService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    it_behaves_like 'raises NoMethodError', 'Subclasses must implement the namespaces_eligible_for_trial method'
  end

  context 'when trial_flow is not implemented' do
    let(:step) { 'trial' }
    let(:test_class) { described_class }

    it_behaves_like 'raises NoMethodError', 'Subclasses must implement the trial_flow method'
  end

  context 'when apply_trial_service_class is not implemented' do
    let(:step) { 'trial' }

    let(:test_class) do
      Class.new(described_class) do
        def namespaces_eligible_for_trial
          Group
        end

        def trial_flow
          existing_namespace_flow
        end
      end
    end

    it_behaves_like 'raises NoMethodError', 'Subclasses must implement the apply_trial_service_class method'
  end

  context 'when tracking_prefix is not implemented' do
    let(:test_class) do
      Class.new(described_class) do
        def lead_service_class
          GitlabSubscriptions::CreateLeadService
        end
      end
    end

    before do
      allow_next_instance_of(GitlabSubscriptions::CreateLeadService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    it_behaves_like 'raises NoMethodError', 'Subclasses must implement the tracking_prefix method'
  end
end
