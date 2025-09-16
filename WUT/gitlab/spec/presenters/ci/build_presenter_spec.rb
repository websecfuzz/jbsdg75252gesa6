# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BuildPresenter, feature_category: :continuous_integration do
  let(:project) { create(:project) }
  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:build) { create(:ci_build, pipeline: pipeline) }

  subject(:presenter) do
    described_class.new(build)
  end

  it 'inherits from Gitlab::View::Presenter::Delegated' do
    expect(described_class.ancestors).to include(Gitlab::View::Presenter::Delegated)
  end

  describe '#initialize' do
    it 'takes a build and optional params' do
      expect { presenter }.not_to raise_error
    end

    it 'exposes build' do
      expect(presenter.build).to eq(build)
    end

    it 'forwards missing methods to build' do
      expect(presenter.ref).to eq('master')
    end
  end

  describe '#status_title' do
    context 'when build is auto-canceled' do
      before do
        expect(build).to receive(:auto_canceled?).and_return(true)
        expect(build).to receive(:auto_canceled_by_id).and_return(1)
      end

      it 'shows that the build is auto-canceled' do
        status_title = presenter.status_title

        expect(status_title).to include('auto-canceled')
        expect(status_title).to include('Pipeline #1')
      end
    end

    context 'when build failed' do
      let(:build) { create(:ci_build, :failed, pipeline: pipeline) }

      it 'returns the reason of failure' do
        status_title = presenter.status_title

        expect(status_title).to eq('Failed - (unknown failure)')
      end
    end

    context 'when build has failed && retried' do
      let(:build) { create(:ci_build, :failed, :retried, pipeline: pipeline) }

      it 'does not include retried title' do
        status_title = presenter.status_title

        expect(status_title).not_to include('(retried)')
        expect(status_title).to eq('Failed - (unknown failure)')
      end
    end

    context 'when build has failed and is allowed to' do
      let(:build) { create(:ci_build, :failed, :allowed_to_fail, pipeline: pipeline) }

      it 'returns the reason of failure' do
        status_title = presenter.status_title

        expect(status_title).to eq('Failed - (unknown failure)')
      end
    end

    context 'For any other build' do
      let(:build) { create(:ci_build, :success, pipeline: pipeline) }

      it 'returns the status' do
        tooltip_description = presenter.status_title

        expect(tooltip_description).to eq('Success')
      end
    end
  end

  describe 'quack like a Ci::Build permission-wise' do
    context 'user is not allowed' do
      let(:project) { create(:project, public_builds: false) }

      it 'returns false' do
        expect(presenter.can?(nil, :read_build)).to be_falsy
      end
    end

    context 'user is allowed' do
      let(:project) { create(:project, :public) }

      it 'returns true' do
        expect(presenter.can?(nil, :read_build)).to be_truthy
      end
    end
  end

  describe '#trigger_variables' do
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:pipeline) { create(:ci_empty_pipeline, project: project) }
    let_it_be_with_reload(:build) { create(:ci_build, pipeline: pipeline) }
    let_it_be(:trigger) { create(:ci_trigger, project: project) }

    context 'when not triggered' do
      it 'returns empty array' do
        expect(presenter.trigger_variables).to eq([])
      end
    end

    context 'when triggered' do
      before do
        pipeline.update!(trigger_id: trigger.id) if pipeline.trigger_id.blank?
      end

      it 'returns empty array' do
        expect(presenter.trigger_variables).to eq([])
      end

      context 'when variable is stored in ci_pipeline_variables' do
        let_it_be(:pipeline_variable) { create(:ci_pipeline_variable, pipeline: pipeline) }

        it 'returns variables' do
          expect(presenter.trigger_variables).to eq([pipeline_variable.to_hash_variable])
        end
      end
    end
  end

  describe '#execute_in' do
    subject { presenter.execute_in }

    context 'when build is scheduled' do
      context 'when schedule is not expired' do
        let(:build) { create(:ci_build, :scheduled) }

        it 'returns execution time' do
          freeze_time do
            is_expected.to be_like_time(60.0)
          end
        end
      end

      context 'when schedule is expired' do
        let(:build) { create(:ci_build, :expired_scheduled) }

        it 'returns execution time' do
          freeze_time do
            is_expected.to eq(0)
          end
        end
      end
    end

    context 'when build is not delayed' do
      let(:build) { create(:ci_build) }

      it 'does not return execution time' do
        freeze_time do
          is_expected.to be_falsy
        end
      end
    end
  end

  describe '#failure_message' do
    let_it_be(:build) { create(:ci_build, :failed, failure_reason: 2) }

    it 'returns a verbose failure message' do
      expect(subject.failure_message).to eq('There has been an API failure, please try again')
    end

    context 'when the build has not failed' do
      let_it_be(:build) { create(:ci_build, :success, failure_reason: 2) }

      it 'does not return any failure message' do
        expect(subject.failure_message).to be_nil
      end
    end
  end

  describe '#callout_failure_message' do
    let(:build) { create(:ci_build, :failed, :api_failure) }

    it 'returns a verbose failure reason' do
      description = subject.callout_failure_message
      expect(description).to eq('There has been an API failure, please try again')
    end
  end
end
