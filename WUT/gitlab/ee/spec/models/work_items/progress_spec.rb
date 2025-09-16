# frozen_string_literal: true
require 'spec_helper'

RSpec.describe WorkItems::Progress, feature_category: :team_planning do
  describe 'associations' do
    it { is_expected.to belong_to(:work_item) }
  end

  describe 'validations' do
    it "ensures progress is an integer greater than to equal to 0 and less than or equal to 100" do
      is_expected.to validate_numericality_of(:progress).only_integer.is_greater_than_or_equal_to(0)
                        .is_less_than_or_equal_to(100)
    end

    %w[start_value end_value current_value reminder_frequency].each do |attribute|
      it "ensures presence of #{attribute}" do
        is_expected.to validate_presence_of(attribute.to_sym)
      end
    end
  end

  describe 'custom validations' do
    describe 'check_start_end_values_to_not_be_same' do
      context 'when start and end values are different' do
        let(:progress) { build(:progress, start_value: 0, end_value: 100) }

        it { is_expected.to be_truthy }
      end

      context 'when start and end values are same' do
        let(:progress) { build(:progress, start_value: 10, end_value: 10) }

        it 'adds an error message' do
          progress.valid?

          expect(progress.errors.full_messages).to contain_exactly(
            'Start value cannot be same as end value'
          )
        end
      end
    end
  end

  describe '#compute_progress' do
    shared_examples 'compute_progress' do |start, finish, current, expected_progress|
      subject(:progress) { build(:progress, start_value: start, end_value: finish, current_value: current) }

      it 'returns the expected progress' do
        expect(progress.compute_progress).to eq(expected_progress)
      end
    end

    context 'when start_value and end_value are the same' do
      context 'when current_value is equal to start_value' do
        it_behaves_like 'compute_progress', 20, 20, 20, 0
      end

      context 'when current_value is not equal to start_value' do
        it_behaves_like 'compute_progress', 20, 20, 10, 0
      end
    end

    context 'when start_value is less than end_value' do
      context 'when current_value is less than start_value' do
        it_behaves_like 'compute_progress', 10, 30, 5, 0
      end

      context 'when current_value is between start_value and end_value' do
        it_behaves_like 'compute_progress', 10, 30, 20, 50
      end

      context 'when current_value is greater than end_value' do
        it_behaves_like 'compute_progress', 10, 30, 40, 100
      end
    end

    context 'when start_value is greater than end_value' do
      context 'when current_value is less than end_value' do
        it_behaves_like 'compute_progress', 30, 10, 5, 100
      end

      context 'when current_value is between end_value and start_value' do
        it_behaves_like 'compute_progress', 30, 10, 20, 50
      end

      context 'when current_value is greater than start_value' do
        it_behaves_like 'compute_progress', 30, 10, 40, 0
      end
    end

    context 'when start_value and end_value are both negative' do
      context 'when current_value is between start_value and end_value' do
        it_behaves_like 'compute_progress', -30, -10, -20, 50
      end
    end

    context 'when start_value and end_value are both default' do
      context 'when current_value is 29' do
        it_behaves_like 'compute_progress', 0.0, 100.0, 29, 29
      end

      context 'when current_value is 94' do
        it_behaves_like 'compute_progress', 0.0, 100.0, 94, 94
      end
    end
  end

  describe '#update_all_parent_objectives_progress' do
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:parent_work_item) { create(:work_item, :objective, project: project) }
    let_it_be_with_reload(:child_work_item1) { create(:work_item, :objective, project: project) }
    let_it_be_with_reload(:child_work_item2) { create(:work_item, :objective, project: project) }
    let_it_be_with_reload(:child1_progress) { create(:progress, work_item: child_work_item1, progress: 20) }

    before_all do
      create(:parent_link, work_item: child_work_item1, work_item_parent: parent_work_item)
      create(:parent_link, work_item: child_work_item2, work_item_parent: parent_work_item)
    end

    before do
      stub_licensed_features(okrs: true)
    end

    shared_examples 'parent progress is not changed' do
      it 'does not schedule progress update for parent' do
        expect(::WorkItems::UpdateParentObjectivesProgressWorker).not_to receive(:perform_async)
        subject
      end
    end

    shared_examples 'schedules progress update' do
      it 'schedules progress update for parent' do
        expect(::WorkItems::UpdateParentObjectivesProgressWorker).to receive(:perform_async)
        subject
      end
    end

    context 'when okr_automatic_rollups feature flag is disabled' do
      before do
        stub_feature_flags(okr_automatic_rollups: false)
      end

      subject { child1_progress.update!(progress: 40) }

      it_behaves_like 'parent progress is not changed'
    end

    context 'when okr_automatic_rollups feature flag is enabled' do
      context 'when progress of child doesnt change' do
        subject { child1_progress.save! }

        it_behaves_like 'parent progress is not changed'
      end

      context 'when rollup_progress is disabled' do
        before do
          child1_progress.update!(rollup_progress: false)
        end

        subject { child1_progress.update!(progress: 50) }

        it_behaves_like 'parent progress is not changed'
      end

      context 'when progress of child changes' do
        context 'when parent progress is not created' do
          subject { child1_progress.update!(progress: 30) }

          it_behaves_like 'schedules progress update'
        end

        context 'when parent progress is created' do
          before do
            create(:progress, work_item: parent_work_item, progress: 10)
          end

          subject { child1_progress.update!(progress: 40) }

          it_behaves_like 'schedules progress update'
        end
      end

      context 'when progress of child 1+ level down changes' do
        let_it_be_with_reload(:child_work_item3) { create(:work_item, :objective, project: project) }
        let_it_be_with_reload(:child_work_item4) { create(:work_item, :objective, project: project) }
        let_it_be_with_reload(:child3_progress) { create(:progress, work_item: child_work_item3, progress: 20) }
        let_it_be_with_reload(:child4_progress) { create(:progress, work_item: child_work_item4, progress: 20) }

        before_all do
          create(:parent_link, work_item: child_work_item3, work_item_parent: child_work_item1)
          create(:parent_link, work_item: child_work_item4, work_item_parent: child_work_item1)
        end
        subject { child3_progress.update!(progress: 80) }

        it_behaves_like 'schedules progress update'
      end
    end
  end
end
