# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries, feature_category: :virtual_registry do
  describe '.registries_count_for' do
    let_it_be(:group) { create(:group) }

    context 'when registry_type is valid' do
      let(:registry_type) { :maven }
      let(:registry_class) { ::VirtualRegistries::Packages::Maven::Registry }
      let(:registries) { instance_double(Array, size: 5) }

      before do
        allow(registry_class).to receive(:for_group).with(group).and_return(registries)
      end

      it 'returns the count of registries for the given group and registry type' do
        expect(described_class.registries_count_for(group, registry_type: registry_type)).to eq(5)
      end

      it 'calls for_group on the registry class with the group' do
        expect(registry_class).to receive(:for_group).with(group)

        described_class.registries_count_for(group, registry_type: registry_type)
      end
    end

    context 'when registry_type is invalid' do
      let(:registry_type) { :invalid_type }

      it 'returns 0' do
        expect(described_class.registries_count_for(group, registry_type: registry_type)).to eq(0)
      end
    end
  end
end
