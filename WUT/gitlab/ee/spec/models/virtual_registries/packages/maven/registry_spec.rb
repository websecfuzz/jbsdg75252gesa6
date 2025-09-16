# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Registry, type: :model, feature_category: :virtual_registry do
  subject(:registry) { build(:virtual_registries_packages_maven_registry) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'has many registry upstream' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::RegistryUpstream')
        .inverse_of(:registry)
    end

    it 'has many upstreams' do
      is_expected.to have_many(:upstreams)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:group_id).scoped_to(:name) }
  end

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
    let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry) }

    subject { described_class.for_group(group) }

    it { is_expected.to eq([registry]) }
  end

  describe 'upstreams ordering' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:upstream1) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registries: [registry])
    end

    let_it_be(:upstream2) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registries: [registry])
    end

    let_it_be(:upstream3) do
      create(:virtual_registries_packages_maven_upstream, group: registry.group, registries: [registry])
    end

    subject { registry.reload.upstreams.to_a }

    it { is_expected.to eq([upstream1, upstream2, upstream3]) }
  end

  describe 'registry destruction' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream) }

    let(:registry) { upstream.registries.first }

    subject(:destroy_registry) { registry.destroy! }

    it 'deletes the upstream and the registry_upstream' do
      expect { destroy_registry }.to change { described_class.count }.by(-1)
        .and change { VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
        .and change { VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
    end

    context 'when the upstream is shared with another registry' do
      before_all do
        create(:virtual_registries_packages_maven_registry, group: upstream.group, name: 'other').tap do |registry|
          create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:)
        end
      end

      it 'does not delete the upstream' do
        expect { destroy_registry }.to change { described_class.count }.by(-1)
          .and change { VirtualRegistries::Packages::Maven::RegistryUpstream.count }.by(-1)
          .and not_change { VirtualRegistries::Packages::Maven::Upstream.count }
      end
    end
  end

  describe '#max_per_group' do
    let(:registry_2) { build(:virtual_registries_packages_maven_registry, group: registry.group) }

    before do
      registry.save!
      stub_const("#{described_class}::MAX_REGISTRY_COUNT", 1)
    end

    it 'does not allow more than one registry per group' do
      expect(registry_2).to be_invalid
        .and have_attributes(errors: hash_including(group: ['1 registries is the maximum allowed per group.']))
    end
  end

  describe '#exclusive_upstreams' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry1, registry2]) }
    let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry1]) }

    subject { registry1.exclusive_upstreams }

    it { is_expected.to eq([upstream2]) }
  end

  describe '#purge_cache!' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream, registries: [registry1, registry2]) }
    let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream, registries: [registry1]) }

    it 'bulk enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker)
        .to receive(:bulk_perform_async_with_contexts)
        .with([upstream2], arguments_proc: kind_of(Proc), context_proc: kind_of(Proc))

      registry1.purge_cache!
    end
  end
end
