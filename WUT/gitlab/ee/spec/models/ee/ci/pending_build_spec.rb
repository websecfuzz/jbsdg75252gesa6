# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PendingBuild, feature_category: :hosted_runners do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:build) { create(:ci_build, :created, pipeline: pipeline, project: project) }

  describe 'scopes' do
    describe '.with_ci_minutes_available' do
      subject(:pending_builds) { described_class.with_ci_minutes_available }

      context 'when pending builds does not have compute minutes available' do
        let!(:pending_build) { create(:ci_pending_build, minutes_exceeded: true) }

        it 'returns an empty collection of pending builds' do
          expect(pending_builds).to be_empty
        end
      end

      context 'when pending builds have compute minutes available' do
        let!(:pending_build) { create(:ci_pending_build, minutes_exceeded: false) }

        it 'returns matching pending builds' do
          expect(pending_builds).to contain_exactly(pending_build)
        end
      end
    end

    describe '.with_allowed_plan_ids' do
      subject(:pending_builds) { described_class.with_allowed_plan_ids([1, 2]) }

      context 'when pending builds are assigned to given plans' do
        let!(:pending_build) { create(:ci_pending_build, plan_id: 1) }

        it 'returns matching pending builds' do
          expect(pending_builds).to contain_exactly(pending_build)
        end
      end

      context 'when pending builds are not assigned to given plans' do
        let!(:pending_build) { create(:ci_pending_build, plan_id: 3) }

        it 'returns an empty collection of pending builds' do
          expect(pending_builds).to be_empty
        end
      end
    end
  end

  describe '.upsert_from_build!' do
    describe 'compute minutes handling' do
      shared_examples 'compute minutes not available' do
        it 'sets minutes_exceeded to true' do
          expect { described_class.upsert_from_build!(build) }.to change(described_class, :count).by(1)

          expect(described_class.last.minutes_exceeded).to be_truthy
        end
      end

      shared_examples 'compute minutes available' do
        it 'sets minutes_exceeded to false' do
          expect { described_class.upsert_from_build!(build) }.to change(described_class, :count).by(1)

          expect(described_class.last.minutes_exceeded).to be_falsey
        end
      end

      context 'when compute minutes are not available' do
        before do
          allow_next_instance_of(::Ci::Minutes::Usage) do |instance|
            allow(instance).to receive(:minutes_used_up?).and_return(true)
          end
        end

        context 'when project matches shared runners with cost factor enabled' do
          before do
            allow(::Ci::Runner).to receive(:any_shared_runners_with_enabled_cost_factor?).and_return(true)
          end

          it_behaves_like 'compute minutes not available'
        end

        context 'when project does not matches shared runners with cost factor enabled' do
          it_behaves_like 'compute minutes available'
        end
      end

      context 'when compute minutes are available' do
        it_behaves_like 'compute minutes available'
      end

      context 'when using shared runners with cost factor disabled' do
        context 'with new project' do
          it_behaves_like 'compute minutes available'
        end
      end
    end

    describe 'subscription plan handling' do
      context 'when project is assigned to a plan', :saas do
        let_it_be(:premium_plan) { create(:premium_plan) }
        let_it_be(:namespace) { create(:namespace_with_plan, plan: :premium_plan) }
        let_it_be(:project) { create(:project, namespace: namespace) }

        it 'sets plan_id' do
          expect { described_class.upsert_from_build!(build) }.to change(described_class, :count).by(1)

          expect(described_class.last.plan_id).to eq(premium_plan.id)
        end
      end

      context 'when not on SaaS' do
        it 'plan_id is empty' do
          expect { described_class.upsert_from_build!(build) }.to change(described_class, :count).by(1)

          expect(described_class.last.plan_id).to be_nil
        end
      end
    end
  end
end
