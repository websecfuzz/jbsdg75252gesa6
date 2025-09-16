# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::BaseCreateAddOnService, feature_category: :subscription_management do
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

  subject(:execute) { test_class.new(**create_params).execute }

  context 'when product_interaction is not implemented' do
    let(:test_class) do
      Class.new(described_class) do
        def namespaces_eligible_for_trial
          Group
        end
      end
    end

    specify do
      expect { execute }.to raise_error(NoMethodError, 'Subclasses must implement the product_interaction method')
    end
  end

  context 'when tracking_prefix is not implemented' do
    let(:test_class) do
      Class.new(described_class) do
        def namespaces_eligible_for_trial
          Group
        end

        def product_interaction
          '_product_interaction_'
        end
      end
    end

    before do
      allow_next_instance_of(GitlabSubscriptions::Trials::CreateAddOnLeadService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    specify do
      expect { execute }.to raise_error(NoMethodError, 'Subclasses must implement the tracking_prefix method')
    end
  end
end
