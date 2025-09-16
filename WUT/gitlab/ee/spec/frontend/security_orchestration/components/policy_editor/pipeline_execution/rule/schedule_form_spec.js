import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/branch_selection.vue';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';
import SnoozeForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/snooze_form.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import {
  DEFAULT_TIME_PER_UNIT,
  MAXIMUM_SECONDS,
  MINIMUM_SECONDS,
  TIME_UNITS,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/constants';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  getHostname: jest.fn().mockReturnValue('gitlab.example.com'),
}));

describe('ScheduleForm', () => {
  let wrapper;
  const defaultSchedule = {
    type: 'daily',
    time_window: { value: 3600 },
    branch_type: 'protected',
  };
  const mockTimezones = [
    { identifier: 'America/New_York', name: 'Eastern Time' },
    { identifier: 'America/Los_Angeles', name: 'Pacific Time' },
  ];

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ScheduleForm, {
      propsData: { schedule: defaultSchedule, ...props },
      stubs: { GlSprintf },
      provide: { timezones: mockTimezones, ...provide },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findTimezoneDropdown = () => wrapper.findComponent(TimezoneDropdown);
  const findTimeDropdown = () => wrapper.findByTestId('time-dropdown');
  const findWeekdayDropdown = () => wrapper.findByTestId('weekday-dropdown');
  const findMonthlyDaysDropdown = () => wrapper.findByTestId('monthly-days-dropdown');
  const findDurationInput = () => wrapper.findByTestId('duration-input');
  const findSnoozeForm = () => wrapper.findComponent(SnoozeForm);
  const findTimeUnitDropdown = () => wrapper.findByTestId('time-unit-dropdown');

  describe('rendering', () => {
    it('displays the message', () => {
      createComponent();
      expect(wrapper.text()).toContain('Schedule to run for');
    });

    it('displays the details', () => {
      createComponent();
      expect(wrapper.text()).toContain('at the following times:');
    });

    it('renders the cadence selector with correct options', () => {
      createComponent();
      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('items')).toEqual([
        { value: 'daily', text: 'Daily' },
        { value: 'weekly', text: 'Weekly' },
        { value: 'monthly', text: 'Monthly' },
      ]);
      expect(listbox.props('toggleText')).toBe('daily');
    });

    it('renders the cadence selector with when the cadence is invalid', () => {
      createComponent({ schedule: { type: 'invalid' } });
      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('toggleText')).toBe('Select a cadence');
    });

    it('sets the selected value based on schedule prop', () => {
      createComponent({ schedule: { type: 'weekly' } });
      expect(findListbox().props('selected')).toBe('weekly');
    });

    // TODO remove this test case after enable dropdown with https://gitlab.com/gitlab-org/gitlab/-/issues/535547
    it('does not render the branch selection component', () => {
      createComponent();
      expect(findBranchSelection().exists()).toBe(false);
    });

    // TODO unskip these test case after enable dropdown with https://gitlab.com/gitlab-org/gitlab/-/issues/535547
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('renders the branch selection component', () => {
      createComponent();
      expect(findBranchSelection().exists()).toBe(true);
      expect(findBranchSelection().props('initRule')).toEqual({
        branch_type: 'protected',
        type: 'daily',
      });
    });

    describe('timezone dropdown', () => {
      it('renders the timezone dropdown with the default timezone', () => {
        createComponent();
        const timezoneDropdown = findTimezoneDropdown();
        expect(timezoneDropdown.exists()).toBe(true);
        expect(timezoneDropdown.props()).toMatchObject({
          timezoneData: mockTimezones,
          value: 'Etc/UTC',
          headerText: 'Select timezone',
        });
        expect(timezoneDropdown.attributes('title')).toBe('on gitlab.example.com');
      });

      it('renders the timezone if specified in the schedule', () => {
        createComponent({ schedule: { type: 'daily', timezone: 'America/New_York' } });
        expect(findTimezoneDropdown().props('value')).toBe('America/New_York');
      });
    });

    it('renders time dropdown', () => {
      createComponent({ schedule: { type: 'daily', start_time: '09:00' } });
      const timeDropdown = findTimeDropdown();
      expect(timeDropdown.exists()).toBe(true);
      expect(timeDropdown.props('selected')).toBe('09:00');
    });

    describe('weekday dropdown', () => {
      it('renders weekday dropdown for weekly schedule', () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        expect(weekdayDropdown.exists()).toBe(true);
        expect(weekdayDropdown.props('selected')).toEqual(['Monday']);
        expect(weekdayDropdown.props('multiple')).toBe(true);
      });

      describe('weekdayToggleText', () => {
        it('returns placeholder when the days property is not available', () => {
          createComponent({ schedule: { type: 'weekly' } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns placeholder when no days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: [] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Select a day');
        });

        it('returns single day when one day is selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday');
        });

        it('returns two days when two days are selected', () => {
          createComponent({ schedule: { type: 'weekly', days: ['Monday', 'Friday'] } });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Friday');
        });

        it('returns truncated text when more than two days are selected', () => {
          createComponent({
            schedule: { type: 'weekly', days: ['Monday', 'Wednesday', 'Friday'] },
          });
          expect(findWeekdayDropdown().props('toggleText')).toBe('Monday, Wednesday +1 more');
        });
      });
    });

    describe('monthly dropdown', () => {
      it('renders monthly days when schedule type is monthly', () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1, 15] } });
        const monthlyDropdown = findMonthlyDaysDropdown();
        expect(monthlyDropdown.exists()).toBe(true);
        expect(monthlyDropdown.props('selected')).toEqual([1, 15]);
        expect(monthlyDropdown.props('multiple')).toBe(true);
      });
    });

    describe('duration controls', () => {
      it('renders the time unit dropdown with correct options', () => {
        createComponent();
        const timeUnitDropdown = findTimeUnitDropdown();
        expect(timeUnitDropdown.exists()).toBe(true);
        expect(timeUnitDropdown.props('items')).toEqual([
          { value: TIME_UNITS.MINUTE, text: 'Minutes' },
          { value: TIME_UNITS.HOUR, text: 'Hours' },
          { value: TIME_UNITS.DAY, text: 'Days' },
        ]);
      });

      it('selects hours as default unit for 3600 seconds (1 hour)', () => {
        createComponent({ schedule: { time_window: { value: 3600 } } });
        expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.HOUR);
        expect(findDurationInput().props('value')).toBe(1);
      });

      it('selects days as default unit for 86400 seconds (1 day)', () => {
        createComponent({ schedule: { time_window: { value: 86400 } } });
        expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.DAY);
        expect(findDurationInput().props('value')).toBe(1);
      });

      it('selects minutes as default unit for non-divisible values', () => {
        createComponent({ schedule: { time_window: { value: 400 } } });
        expect(findTimeUnitDropdown().props('selected')).toBe(TIME_UNITS.MINUTE);
        expect(findDurationInput().props('value')).toBe(6);
      });

      it('uses minimum value of 10 when duration would be 0', () => {
        createComponent({ schedule: { time_window: { value: 0 } } });
        expect(findDurationInput().props('value')).toBe(10);
      });
    });

    describe('SnoozeForm', () => {
      it('passes snooze data to SnoozeForm component', () => {
        const snoozeData = {
          until: '2025-06-01T00:00:00Z',
          reason: 'Maintenance period',
        };
        createComponent({ schedule: { snooze: snoozeData } });
        expect(findSnoozeForm().props('data')).toEqual(snoozeData);
      });
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    // TODO unskip these test case after enable dropdown with https://gitlab.com/gitlab-org/gitlab/-/issues/535547
    // eslint-disable-next-line jest/no-disabled-tests
    describe.skip('branch selection', () => {
      it('handles branch type selection changes', async () => {
        const branchTypeData = { branch_type: 'all' };
        await findBranchSelection().vm.$emit('set-branch-type', branchTypeData);
        expect(wrapper.emitted('changed')).toMatchObject([[{ ...branchTypeData }]]);
      });

      it('handles branches selection changes', async () => {
        const branchesData = { branches: ['main'] };
        await findBranchSelection().vm.$emit('changed', branchesData);
        expect(wrapper.emitted('changed')).toMatchObject([[{ ...branchesData }]]);
      });
    });

    describe('cadence', () => {
      it('emits changed event with daily schedule when daily is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'daily');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'daily', time_window: { value: 60 } }],
        ]);
      });

      it('emits changed event with weekly schedule when weekly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'weekly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'weekly', days: ['Monday'], time_window: { value: 86400 } }],
        ]);
      });

      it('emits changed event with monthly schedule when monthly is selected', async () => {
        createComponent();
        await findListbox().vm.$emit('select', 'monthly');

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')).toMatchObject([
          [{ type: 'monthly', days_of_month: [1], time_window: { value: 86400 } }],
        ]);
      });

      it('removes irrelevant properties when changing cadence type', async () => {
        createComponent({
          schedule: {
            type: 'daily',
            start_time: '12:00',
            days: ['Friday'],
            days_of_month: '15',
            time_window: { value: 3600 },
          },
        });

        await findListbox().vm.$emit('select', 'weekly');

        const emittedSchedule = wrapper.emitted('changed')[0][0];
        expect(emittedSchedule).toHaveProperty('days');
        expect(emittedSchedule).toHaveProperty('start_time');
        expect(emittedSchedule).not.toHaveProperty('days_of_month');
      });
    });

    describe('timezone', () => {
      it('handles timezone selection changes', async () => {
        const timezoneData = { identifier: 'America/Los_Angeles' };
        await findTimezoneDropdown().vm.$emit('input', timezoneData);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ timezone: timezoneData.identifier })],
        ]);
      });
    });

    describe('time dropdown', () => {
      it('emits changed event when time is selected', async () => {
        const timeDropdown = findTimeDropdown();
        await timeDropdown.vm.$emit('select', '10:00');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ start_time: '10:00' })],
        ]);
      });
    });

    describe('weekday dropdown', () => {
      it('emits changed event when days are selected', async () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        await weekdayDropdown.vm.$emit('select', ['Monday', 'Wednesday']);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days: ['Monday', 'Wednesday'] })],
        ]);
      });

      it('emits changed event when days are reset', async () => {
        createComponent({ schedule: { type: 'weekly', days: ['Monday'] } });
        const weekdayDropdown = findWeekdayDropdown();
        await weekdayDropdown.vm.$emit('reset');
        expect(wrapper.emitted('changed')).toEqual([[expect.objectContaining({ days: [] })]]);
      });
    });

    describe('monthly dropdown', () => {
      it('emits changed event when days are selected', async () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1] } });
        await findMonthlyDaysDropdown().vm.$emit('select', [1, 15, 2]);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days_of_month: [1, 2, 15] })],
        ]);
      });

      it('emits changed event when days are reset', async () => {
        createComponent({ schedule: { type: 'monthly', days_of_month: [1] } });
        await findMonthlyDaysDropdown().vm.$emit('reset');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ days_of_month: [] })],
        ]);
      });
    });

    describe('duration controls', () => {
      it('updates time_window.value when duration value changes', async () => {
        createComponent({ schedule: { time_window: { value: 3600 } } });
        await findDurationInput().vm.$emit('update', 2);

        expect(wrapper.emitted('changed')).toEqual([
          [{ time_window: { value: 7200 } }], // 2 hours = 7200 seconds
        ]);
      });

      it('applies minimum limit when duration is too small', async () => {
        createComponent({ schedule: { time_window: { value: 1 } } });
        await findDurationInput().vm.$emit('update', 1);

        // With TIME_UNITS.MINUTE selected, 1 minute = 60 seconds, which is below MINIMUM_SECONDS (600)
        // So it should be capped at MINIMUM_SECONDS
        expect(wrapper.emitted('changed')[0][0].time_window.value).toBe(MINIMUM_SECONDS);
      });

      it('applies maximum limit when duration is too large', async () => {
        createComponent({ schedule: { time_window: { value: 3600 } } });
        // Set time unit to days first
        await findTimeUnitDropdown().vm.$emit('select', TIME_UNITS.DAY);

        // Then set a very large number of days
        await findDurationInput().vm.$emit('update', 100);

        // 100 days exceeds MAXIMUM_SECONDS, so it should be capped
        expect(wrapper.emitted('changed')[1][0].time_window.value).toBe(MAXIMUM_SECONDS);
      });

      it('uses DEFAULT_TIME_PER_UNIT when time unit changes', async () => {
        createComponent({ schedule: { time_window: { value: 3600 } } });
        await findTimeUnitDropdown().vm.$emit('select', TIME_UNITS.DAY);

        expect(wrapper.emitted('changed')[0][0].time_window.value).toBe(
          DEFAULT_TIME_PER_UNIT[TIME_UNITS.DAY],
        );
      });

      it.each(['', undefined, null, 'hello'])('ignores the input $input', async (input) => {
        createComponent({ schedule: { time_window: { value: 3600 } } });
        await findDurationInput().vm.$emit('update', input);

        // Should not emit a change event for empty input
        expect(wrapper.emitted('changed')).toBe(undefined);
      });
    });

    describe('snooze form', () => {
      it('handles update events', () => {
        createComponent();

        const snoozeData = {
          until: '2025-06-01T00:00:00Z',
          reason: 'Maintenance period',
        };

        findSnoozeForm().vm.$emit('update', snoozeData);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toEqual({
          ...defaultSchedule,
          snooze: snoozeData,
        });
      });
    });
  });
});
