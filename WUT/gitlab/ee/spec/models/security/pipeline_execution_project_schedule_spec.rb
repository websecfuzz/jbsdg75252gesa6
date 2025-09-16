# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionProjectSchedule, feature_category: :security_policy_management do
  describe 'validations' do
    let(:schedule) { build(:security_pipeline_execution_project_schedule) }

    subject { schedule }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:security_policy) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:cron) }
    it { is_expected.to validate_presence_of(:cron_timezone) }
    it { is_expected.to validate_presence_of(:time_window_seconds) }

    it 'validates time_window_seconds limits' do
      is_expected.to(
        validate_numericality_of(:time_window_seconds)
          .is_greater_than_or_equal_to(10.minutes.to_i)
          .is_less_than_or_equal_to(Security::PipelineExecutionProjectSchedule::MAX_TIME_WINDOW.to_i)
          .only_integer
      )
    end

    context 'when security policy is not a pipeline_execution_schedule_policy' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_policy) }
      let(:schedule) { build(:security_pipeline_execution_project_schedule, security_policy: security_policy) }

      it { is_expected.not_to be_valid }
    end

    describe 'cron validation' do
      context 'with valid crontab' do
        before do
          schedule.cron = "* * * * *"
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid crontab' do
        before do
          schedule.cron = "a b c d e"
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'cron timezone validation' do
      context 'with valid cron_timezone' do
        before do
          schedule.cron_timezone = "Europe/Berlin"
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid cron_timezone' do
        before do
          schedule.cron_timezone = "Europe/New_York"
        end

        it { is_expected.to be_invalid }
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy).class_name('Security::Policy') }
  end

  describe 'scopes' do
    describe '.for_project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule, project: project) }
      let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule) }

      it 'returns schedules for the given project' do
        expect(described_class.for_project(project)).to contain_exactly(schedule)
      end
    end

    describe '.runnable_schedules' do
      let_it_be(:runnable_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:future_schedule) { create(:security_pipeline_execution_project_schedule) }

      before do
        runnable_schedule.update!(next_run_at: 1.hour.ago)
        future_schedule.update!(next_run_at: 1.hour.from_now)
      end

      it 'returns schedules that are due to run' do
        expect(described_class.runnable_schedules).to contain_exactly(runnable_schedule)
      end
    end

    describe '.ordered_by_next_run_at' do
      let_it_be(:monthly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:weekly_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:daily_schedule) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:daily_schedule_2) { create(:security_pipeline_execution_project_schedule) }

      before do
        monthly_schedule.update!(next_run_at: Time.zone.now + 1.month)
        weekly_schedule.update!(next_run_at: Time.zone.now + 1.week)

        # Use the same time for both records to ensure the order by id is correct.
        daily_schedule_time = Time.zone.now + 1.day
        daily_schedule.update!(next_run_at: daily_schedule_time)
        daily_schedule_2.update!(next_run_at: daily_schedule_time)
      end

      it 'returns schedules ordered by next_run_at and id' do
        expect(described_class.ordered_by_next_run_at).to eq(
          [daily_schedule, daily_schedule_2, weekly_schedule, monthly_schedule]
        )
      end
    end

    describe '.including_security_policy_and_project' do
      let_it_be(:schedule_1) { create(:security_pipeline_execution_project_schedule) }
      let_it_be(:schedule_2) { create(:security_pipeline_execution_project_schedule) }

      it 'preloads security_policy and project' do
        recorder = ActiveRecord::QueryRecorder.new do
          schedules = described_class.including_security_policy_and_project

          schedules.each do |schedule|
            schedule.security_policy
            schedule.project
          end
        end

        # 1. Load schedules
        # 2. Load security_policy
        # 3. Load project
        expect(recorder.count).to eq(3)
      end
    end

    describe '.for_policy' do
      let_it_be(:policy) { create(:security_policy, :pipeline_execution_schedule_policy) }
      let_it_be(:schedule) { create(:security_pipeline_execution_project_schedule, security_policy: policy) }
      let_it_be(:other_schedule) { create(:security_pipeline_execution_project_schedule) }

      it 'returns schedules for the given policy' do
        expect(described_class.for_policy(policy)).to contain_exactly(schedule)
      end
    end
  end

  describe 'callbacks' do
    describe 'update next_run_at on create', time_travel_to: '2024-12-20 00:00:00' do
      let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

      let(:schedule) do
        build(
          :security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          cron: "0 0 * * *")
      end

      subject(:save!) { schedule.save! }

      it 'sets next_run_at to the next cron run based on current time' do
        save!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end
  end

  describe 'schedule_next_run!', time_travel_to: '2024-12-20 00:00:00' do
    let(:schedule) { create(:security_pipeline_execution_project_schedule, cron: "0 0 * * *") }

    subject(:schedule_next_run!) { schedule.schedule_next_run! }

    it 'updates next_run_at to the next cron run based on current time' do
      schedule_next_run!

      expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
    end

    context 'when new next_run_at value would result in a time in the past' do
      before do
        schedule.next_run_at = 1.year.ago
      end

      it 'updates next_run_at to the next cron run based on current time' do
        schedule_next_run!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end

    context 'when next_run_at is nil' do
      before do
        schedule.next_run_at = nil
      end

      it 'sets next_run_at to the next cron run based on current time' do
        schedule_next_run!

        expect(schedule.next_run_at).to eq(Time.zone.now + 1.day)
      end
    end
  end

  describe '#ci_content' do
    subject(:ci_content) { build(:security_pipeline_execution_project_schedule).ci_content }

    it 'returns the security policy CI config content' do
      expect(ci_content).to eq(
        'include' => [{ 'project' => 'compliance-project', 'file' => 'compliance-pipeline.yml' }])
    end
  end

  describe '#next_run_in' do
    let(:schedule) { build(:security_pipeline_execution_project_schedule, cron: cron) }

    subject(:next_run_in) { schedule.next_run_in }

    context 'with daily schedule' do
      let(:cron) { "0 0 * * *" }

      it 'returns 24 hours from beginning of the day' do
        travel_to(Time.zone.now.beginning_of_day) do
          expect(next_run_in).to eq(1.day)
        end
      end

      it 'returns 12 hours from noon of the day' do
        travel_to(Time.zone.now.beginning_of_day + 12.hours) do
          expect(next_run_in).to eq(12.hours)
        end
      end
    end

    context 'with weekly schedule running Tuesday and Saturday' do
      let(:cron) { '0 0 * * 2,6' }

      it 'returns 4 days from Tuesday' do
        travel_to(Time.zone.parse('2025-03-18 00:00:00')) do
          expect(next_run_in).to eq(4.days)
        end
      end

      it 'returns 1 day from Monday' do
        travel_to(Time.zone.parse('2025-03-17 00:00:00')) do
          expect(next_run_in).to eq(1.day)
        end
      end
    end
  end

  describe '#snoozed?' do
    subject(:snoozed?) { schedule.snoozed? }

    context 'when snoozed_until is nil' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: nil) }

      it { is_expected.to be(false) }
    end

    context 'when snoozed_until is in the future' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: 1.day.from_now) }

      it { is_expected.to be(true) }
    end

    context 'when snoozed_until is in the past' do
      let(:schedule) { build(:security_pipeline_execution_project_schedule, snoozed_until: 1.day.ago) }

      it { is_expected.to be(false) }
    end
  end

  describe '#branches' do
    let_it_be(:project) { create(:project, :repository) }

    let(:security_policy) { build(:security_policy, :pipeline_execution_schedule_policy) }
    let(:schedule) do
      build(:security_pipeline_execution_project_schedule, security_policy: security_policy, project: project)
    end

    subject(:branches) { schedule.branches }

    it { is_expected.to eq(['master']) }

    context 'when security policy content has branches' do
      let(:security_policy) { build(:security_policy, :pipeline_execution_schedule_policy, content: policy_content) }
      let(:branches_content) { %w[branch-1 branch-2] }

      let(:policy_content) do
        {
          content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
          schedules: [
            { type: "daily", start_time: "00:00", time_window: { value: 4000, distribution: 'random' },
              branches: branches_content }
          ]
        }
      end

      it { is_expected.to eq(branches_content) }

      context 'when the same branch is used twice' do
        let(:branches_content) { %w[branch-1 branch-1] }

        it { is_expected.to eq(%w[branch-1]) }
      end
    end
  end
end
