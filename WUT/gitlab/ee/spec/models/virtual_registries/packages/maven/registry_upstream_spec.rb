# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::RegistryUpstream, type: :model, feature_category: :virtual_registry do
  subject(:registry_upstream) { build(:virtual_registries_packages_maven_registry_upstream) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'belongs to a registry' do
      is_expected.to belong_to(:registry)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
        .inverse_of(:registry_upstreams)
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
        .inverse_of(:registry_upstreams)
    end
  end

  describe 'validations' do
    subject(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:upstream_id).scoped_to(:registry_id) }

    it 'validates position' do
      is_expected.to validate_numericality_of(:position)
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(20)
        .only_integer
    end

    # position is set before validation on create. Thus, we need to check the registry_id uniqueness validation
    # manually with two records that are already persisted.
    context 'for registry_id uniqueness' do
      let_it_be(:other_registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream) }

      it 'validates it' do
        other_registry_upstream.assign_attributes(registry_upstream.attributes)

        expect(other_registry_upstream.valid?).to be_falsey
        expect(other_registry_upstream.errors[:registry_id].first).to eq('has already been taken')
      end
    end
  end

  describe '#update_position' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:registry_upstreams) do
      create_list(:virtual_registries_packages_maven_registry_upstream, 4, registry:)
    end

    context 'when position is unchanged' do
      it 'does not update any positions' do
        expect { registry_upstreams[0].update_position(1) }.not_to change { reload_positions }
      end
    end

    context 'when moving to a lower position' do
      it 'updates the position of the target and increments positions of items in between' do
        registry_upstreams[0].update_position(3)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 3,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 4
        })
      end

      it 'handles moving to the lowest position' do
        registry_upstreams[0].update_position(4)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 4,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })
      end
    end

    context 'when moving to a higher position' do
      it 'updates the position of the target and decrements positions of items in between' do
        registry_upstreams[3].update_position(2)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 3,
          registry_upstreams[2].id => 4,
          registry_upstreams[3].id => 2
        })
      end

      it 'handles moving to the highest position' do
        registry_upstreams[3].update_position(1)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 2,
          registry_upstreams[1].id => 3,
          registry_upstreams[2].id => 4,
          registry_upstreams[3].id => 1
        })
      end
    end

    context 'when moving to a position beyond the maximum' do
      it 'caps the position at the maximum existing position' do
        registry_upstreams[1].update_position(10)

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 4,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })
      end
    end

    context 'when there are multiple registries' do
      let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry) }
      let_it_be_with_reload(:other_registry_upstreams) do
        create_list(:virtual_registries_packages_maven_registry_upstream, 2, registry: other_registry)
      end

      it 'only updates positions within the same registry' do
        registry_upstreams[0].update_position(3)

        # Positions in the original registry should be updated
        expect(reload_positions).to eq({
          registry_upstreams[0].id => 3,
          registry_upstreams[1].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 4
        })

        # Positions in the other registry should remain unchanged
        expect(other_registry_upstreams[0].position).to eq(1)
        expect(other_registry_upstreams[1].position).to eq(2)
      end
    end
  end

  describe '.sync_higher_positions' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

    let_it_be_with_refind(:registry_upstreams) do
      create_list(:virtual_registries_packages_maven_registry_upstream, 4, registry:)
    end

    it 'decrements positions of all registry upstreams with higher positions' do
      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[1].id => 2,
        registry_upstreams[2].id => 3,
        registry_upstreams[3].id => 4
      })

      described_class.sync_higher_positions(registry_upstreams[1].upstream.registry_upstreams)
      registry_upstreams[1].destroy!

      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[2].id => 2,
        registry_upstreams[3].id => 3
      })
    end

    context 'when there are shared upstreams' do
      let_it_be(:other_registry) do
        create(:virtual_registries_packages_maven_registry, group: registry.group, name: 'other')
      end

      let_it_be(:registry_upstream_1) do
        create(:virtual_registries_packages_maven_registry_upstream, registry: other_registry,
          upstream: registry_upstreams[0].upstream)
      end

      let_it_be(:registry_upstream_2) do
        create(:virtual_registries_packages_maven_registry_upstream, registry: other_registry,
          upstream: registry_upstreams[1].upstream)
      end

      it 'correctly updates positions in all registries' do
        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[1].id => 2,
          registry_upstreams[2].id => 3,
          registry_upstreams[3].id => 4
        })

        expect(reload_positions(other_registry)).to eq({
          registry_upstream_1.id => 1,
          registry_upstream_2.id => 2
        })

        described_class.sync_higher_positions(
          described_class.where(upstream_id: [registry_upstreams[1].upstream_id, registry_upstream_1.upstream_id])
        )
        registry_upstreams[1].destroy!
        registry_upstream_1.destroy!

        expect(reload_positions).to eq({
          registry_upstreams[0].id => 1,
          registry_upstreams[2].id => 2,
          registry_upstreams[3].id => 3
        })

        expect(reload_positions(other_registry)).to eq({
          registry_upstream_2.id => 1
        })
      end
    end
  end

  describe '#sync_higher_positions' do
    let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:registry_upstreams) do
      create_list(:virtual_registries_packages_maven_registry_upstream, 4, registry:)
    end

    it 'decrements positions of all registry upstreams with higher positions' do
      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[1].id => 2,
        registry_upstreams[2].id => 3,
        registry_upstreams[3].id => 4
      })

      registry_upstreams[1].destroy!
      registry_upstreams[1].sync_higher_positions

      expect(reload_positions).to eq({
        registry_upstreams[0].id => 1,
        registry_upstreams[2].id => 2,
        registry_upstreams[3].id => 3
      })
    end
  end

  def reload_positions(registry = registry_upstreams[0].registry)
    described_class.where(registry:).pluck(:id, :position).to_h
  end
end
