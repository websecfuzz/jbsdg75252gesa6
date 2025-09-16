# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :duo_chat do
  subject(:policy) { described_class.new(nil, item_consumer) }

  let_it_be(:item_consumer) { build(:ai_catalog_item_consumer, project: build(:project)) }

  it 'delegates to ProjectPolicy' do
    delegations = policy.delegated_policies

    expect(delegations.size).to eq(1)
    expect(delegations.each_value.first).to be_instance_of(::ProjectPolicy)
  end
end
