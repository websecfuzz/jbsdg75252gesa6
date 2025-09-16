# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypeCustomLifecycle, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
  let(:work_item_type) { create(:work_item_type, :task, namespace: group) }

  subject(:type_custom_lifecycle) do
    build_stubbed(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type)
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item_type) }
    it { is_expected.to belong_to(:lifecycle).class_name('WorkItems::Statuses::Custom::Lifecycle') }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:work_item_type) }
    it { is_expected.to validate_presence_of(:lifecycle) }

    describe 'uniqueness validation' do
      subject(:type_custom_lifecycle) do
        create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type)
      end

      it { is_expected.to validate_uniqueness_of(:lifecycle).scoped_to([:namespace_id, :work_item_type_id]) }
    end
  end

  describe '#validate_status_widget_availability' do
    context 'when work item type supports status widget' do
      it 'is valid' do
        expect(type_custom_lifecycle).to be_valid
      end
    end

    context 'when work item type does not support status widget' do
      let(:work_item_type) { create(:work_item_type, :requirement, namespace: group) }

      it 'is invalid' do
        expect(type_custom_lifecycle).to be_invalid
        expect(type_custom_lifecycle.errors[:work_item_type]).to include('does not support status widget')
      end

      context 'when work_item_status licensed feature is not available' do
        before do
          stub_licensed_features(work_item_status: false)
        end

        it 'is invalid' do
          expect(type_custom_lifecycle).to be_invalid
          expect(type_custom_lifecycle.errors[:work_item_type]).to include('does not support status widget')
        end
      end

      context 'when work_item_status_feature_flag feature flag is disabled' do
        before do
          stub_feature_flags(work_item_status_feature_flag: false)
        end

        it 'is invalid' do
          expect(type_custom_lifecycle).to be_invalid
          expect(type_custom_lifecycle.errors[:work_item_type]).to include('does not support status widget')
        end
      end
    end
  end

  describe 'callbacks' do
    describe '#copy_namespace_from_lifecycle' do
      context 'when namespace is not set' do
        subject(:type_custom_lifecycle) do
          build_stubbed(:work_item_type_custom_lifecycle, namespace: nil, lifecycle: lifecycle,
            work_item_type: work_item_type)
        end

        it 'copies namespace from lifecycle' do
          expect { type_custom_lifecycle.valid? }
            .to change { type_custom_lifecycle.namespace }
            .from(nil).to(lifecycle.namespace)
        end
      end

      context 'when namespace is already set' do
        it 'does not override the namespace' do
          expect { type_custom_lifecycle.valid? }
            .not_to change { type_custom_lifecycle.namespace }

          expect(type_custom_lifecycle.namespace).to eq(lifecycle.namespace)
        end
      end
    end
  end
end
