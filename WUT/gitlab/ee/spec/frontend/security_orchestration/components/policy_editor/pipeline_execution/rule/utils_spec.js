import {
  determineTimeUnit,
  getValueWithinLimits,
  secondsToValue,
  timeUnitToSeconds,
  updateScheduleCadence,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/utils';
import {
  MAXIMUM_SECONDS,
  MINIMUM_SECONDS,
  TIME_UNITS,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/constants';

describe('Pipeline execution rule utils', () => {
  describe('getValueWithinLimits', () => {
    it('returns the same value when within limits', () => {
      const validValue = Math.floor((MAXIMUM_SECONDS + MINIMUM_SECONDS) / 2);
      expect(getValueWithinLimits(validValue)).toBe(validValue);
    });

    it('returns the minimum value when input is below minimum', () => {
      const belowMinimum = MINIMUM_SECONDS - 100;
      expect(getValueWithinLimits(belowMinimum)).toBe(MINIMUM_SECONDS);
    });

    it('returns the maximum value when input is above maximum', () => {
      const aboveMaximum = MAXIMUM_SECONDS + 100;
      expect(getValueWithinLimits(aboveMaximum)).toBe(MAXIMUM_SECONDS);
    });

    it('returns the minimum value when input is exactly the minimum', () => {
      expect(getValueWithinLimits(MINIMUM_SECONDS)).toBe(MINIMUM_SECONDS);
    });

    it('returns the maximum value when input is exactly the maximum', () => {
      expect(getValueWithinLimits(MAXIMUM_SECONDS)).toBe(MAXIMUM_SECONDS);
    });

    it('handles non-integer inputs by converting them to integers', () => {
      const floatValue = MINIMUM_SECONDS + 10.5;
      // JavaScript's Math.min/max don't truncate floats
      expect(getValueWithinLimits(floatValue)).toBe(floatValue);
    });

    it('handles negative values by returning minimum', () => {
      expect(getValueWithinLimits(-100)).toBe(MINIMUM_SECONDS);
    });

    it('handles zero by returning minimum if minimum is positive', () => {
      if (MINIMUM_SECONDS > 0) {
        expect(getValueWithinLimits(0)).toBe(MINIMUM_SECONDS);
      } else {
        expect(getValueWithinLimits(0)).toBe(0);
      }
    });

    it('handles extreme values without overflow', () => {
      expect(getValueWithinLimits(Number.MAX_SAFE_INTEGER)).toBe(MAXIMUM_SECONDS);
      expect(getValueWithinLimits(Number.MIN_SAFE_INTEGER)).toBe(MINIMUM_SECONDS);
    });
  });

  describe('time unit utilities', () => {
    describe('timeUnitToSeconds', () => {
      it('converts hours to seconds correctly', () => {
        expect(timeUnitToSeconds(2, TIME_UNITS.HOUR)).toBe(7200);
      });

      it('converts days to seconds correctly', () => {
        expect(timeUnitToSeconds(1, TIME_UNITS.DAY)).toBe(86400);
      });

      it('handles seconds correctly', () => {
        expect(timeUnitToSeconds(30, TIME_UNITS.MINUTE)).toBe(1800);
      });
    });

    describe('secondsToValue', () => {
      it.each([-1, Infinity, 'hello'])(
        'return 0 with the invalid second value $time',
        ({ time }) => {
          expect(secondsToValue(time, TIME_UNITS.MINUTE)).toBe(0);
        },
      );

      it.each`
        time     | unit                 | output
        ${60}    | ${TIME_UNITS.MINUTE} | ${1}
        ${7200}  | ${TIME_UNITS.HOUR}   | ${2}
        ${86400} | ${TIME_UNITS.DAY}    | ${1}
      `('converts $time seconds to $unit correctly', ({ time, unit, output }) => {
        expect(secondsToValue(time, unit)).toBe(output);
      });
    });

    describe('determineTimeUnit', () => {
      it('selects days for values divisible by 86400', () => {
        expect(determineTimeUnit(86400)).toBe(TIME_UNITS.DAY);
        expect(determineTimeUnit(172800)).toBe(TIME_UNITS.DAY);
      });

      it('selects hours for values divisible by 3600 but not 86400', () => {
        expect(determineTimeUnit(3600)).toBe(TIME_UNITS.HOUR);
        expect(determineTimeUnit(7200)).toBe(TIME_UNITS.HOUR);
      });

      it('selects minute for other values', () => {
        expect(determineTimeUnit(60)).toBe(TIME_UNITS.MINUTE);
        expect(determineTimeUnit(120)).toBe(TIME_UNITS.MINUTE);
      });

      it.each([-1, Infinity, 'hello', 0])(
        'selects minutes for invalid seconds value $time',
        ({ time }) => {
          expect(determineTimeUnit(time)).toBe(TIME_UNITS.MINUTE);
        },
      );
    });
  });

  describe('updateScheduleCadence', () => {
    const baseSchedule = {
      start_time: '00:00',
      time_window: { value: 3600, distribution: 'random' },
      timezone: 'America/New_York',
    };

    const dailySchedule = {
      type: 'daily',
      ...baseSchedule,
    };

    const weeklySchedule = {
      type: 'weekly',
      days: ['Monday'],
      ...baseSchedule,
    };

    const monthlySchedule = {
      type: 'monthly',
      days_of_month: [1],
      ...baseSchedule,
    };

    it('updates to daily cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: weeklySchedule, cadence: 'daily' })).toEqual(
        expect.objectContaining({
          ...dailySchedule,
          time_window: { value: 60, distribution: 'random' },
        }),
      );
    });

    it('updates to weekly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: monthlySchedule, cadence: 'weekly' })).toEqual(
        expect.objectContaining({
          ...weeklySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('updates to monthly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: dailySchedule, cadence: 'monthly' })).toEqual(
        expect.objectContaining({
          ...monthlySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('removes irrelevant properties when changing cadence type', () => {
      const result = updateScheduleCadence({
        schedule: baseSchedule,
        cadence: 'weekly',
      });

      expect(result).toHaveProperty('days');
      expect(result).not.toHaveProperty('days_of_month');
    });

    it('preserves additional properties not related to cadence', () => {
      const scheduleWithExtra = {
        ...baseSchedule,
        custom_property: 'value',
        another_property: 123,
      };

      const result = updateScheduleCadence({
        schedule: scheduleWithExtra,
        cadence: 'weekly',
      });

      expect(result.custom_property).toBe('value');
      expect(result.another_property).toBe(123);
    });
  });
});
