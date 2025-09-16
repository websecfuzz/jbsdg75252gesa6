import {
  renameKey,
  getReferrersCache,
  addExperimentContext,
  addReferrersCacheEntry,
  filterOldReferrersCacheEntries,
  InternalEventHandler,
  createInternalEventPayload,
  validateAdditionalProperties,
  getCustomAdditionalProperties,
  getBaseAdditionalProperties,
  validateEvent,
  isEventEligible,
} from '~/tracking/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { TRACKING_CONTEXT_SCHEMA } from '~/experimentation/constants';
import { REFERRER_TTL, URLS_CACHE_STORAGE_KEY } from '~/tracking/constants';
import { TEST_HOST } from 'helpers/test_constants';

jest.mock('~/experimentation/utils', () => ({
  getExperimentData: jest.fn().mockReturnValue({}),
}));

describe('~/tracking/utils', () => {
  beforeEach(() => {
    window.gl = window.gl || {};
    window.gl.snowplowStandardContext = {};
  });

  describe('addExperimentContext', () => {
    const options = {
      category: 'root:index',
      action: 'generic',
    };

    it('returns same options if no experiment is provided', () => {
      expect(addExperimentContext({ options })).toStrictEqual({ options });
    });

    it('adds experiment if provided', () => {
      const experiment = 'TEST_EXPERIMENT_NAME';

      expect(addExperimentContext({ experiment, ...options })).toStrictEqual({
        ...options,
        context: { data: {}, schema: TRACKING_CONTEXT_SCHEMA },
      });
    });
  });

  describe('renameKey', () => {
    it('renames a given key', () => {
      expect(renameKey({ allow: [] }, 'allow', 'permit')).toStrictEqual({ permit: [] });
    });
  });

  describe('referrers cache', () => {
    describe('filterOldReferrersCacheEntries', () => {
      it('removes entries with old or no timestamp', () => {
        const now = Date.now();
        const cache = [{ timestamp: now }, { timestamp: now - REFERRER_TTL }, { referrer: '' }];

        expect(filterOldReferrersCacheEntries(cache)).toStrictEqual([{ timestamp: now }]);
      });
    });

    describe('getReferrersCache', () => {
      beforeEach(() => {
        localStorage.removeItem(URLS_CACHE_STORAGE_KEY);
      });

      it('returns an empty array if cache is not found', () => {
        expect(getReferrersCache()).toHaveLength(0);
      });

      it('returns an empty array if cache is invalid', () => {
        localStorage.setItem(URLS_CACHE_STORAGE_KEY, 'Invalid JSON');

        expect(getReferrersCache()).toHaveLength(0);
      });

      it('returns parsed entries if valid', () => {
        localStorage.setItem(
          URLS_CACHE_STORAGE_KEY,
          JSON.stringify([{ referrer: '', timestamp: Date.now() }]),
        );

        expect(getReferrersCache()).toHaveLength(1);
      });
    });

    describe('addReferrersCacheEntry', () => {
      it('unshifts entry and adds timestamp', () => {
        const now = Date.now();

        addReferrersCacheEntry([{ referrer: '', originalUrl: TEST_HOST, timestamp: now }], {
          referrer: TEST_HOST,
        });

        const cache = getReferrersCache();

        expect(cache).toHaveLength(2);
        expect(cache[0].referrer).toBe(TEST_HOST);
        expect(cache[0].timestamp).toBeDefined();
      });
    });

    describe('createInternalEventPayload', () => {
      it('should return event name from element', () => {
        const mockEl = { dataset: { eventTracking: 'click' } };
        const result = createInternalEventPayload(mockEl);
        expect(result).toEqual({ additionalProperties: {}, event: 'click' });
      });
      it('should return event and additional Properties from element', () => {
        const mockEl = {
          dataset: {
            eventTracking: 'click',
            eventProperty: 'test-property',
            eventLabel: 'test-label',
            eventValue: 2,
          },
        };
        const result = createInternalEventPayload(mockEl);
        expect(result).toEqual({
          additionalProperties: { property: 'test-property', label: 'test-label', value: 2 },
          event: 'click',
        });
      });

      it('should return event and parse eventAdditional JSON into additionalProperties', () => {
        const mockEl = {
          dataset: {
            eventTracking: 'click',
            eventAdditional: '{"key": "value"}',
          },
        };
        const result = createInternalEventPayload(mockEl);
        expect(result).toEqual({
          event: 'click',
          additionalProperties: { key: 'value' },
        });
      });

      it('should handle invalid JSON in eventAdditional gracefully', () => {
        const mockEl = {
          dataset: {
            eventTracking: 'click',
            eventAdditional: '{invalidJson}',
          },
        };
        const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

        const result = createInternalEventPayload(mockEl);
        expect(result).toEqual({
          event: 'click',
          additionalProperties: {},
        });
        expect(consoleErrorSpy).toHaveBeenCalledWith(
          'Failed to parse eventAdditional attribute:',
          '{invalidJson}',
        );

        consoleErrorSpy.mockRestore();
      });
    });

    describe('InternalEventHandler', () => {
      it.each([
        ['should call the provided function with the correct event payload', 'click', true],
        [
          'should not call the provided function if the closest matching element is not found',
          null,
          false,
        ],
      ])('%s', (_, payload, shouldCallFunc) => {
        const mockFunc = jest.fn();
        const mockEl = payload ? { dataset: { eventTracking: payload } } : null;
        const mockEvent = {
          target: {
            closest: jest.fn().mockReturnValue(mockEl),
          },
        };

        InternalEventHandler(mockEvent, mockFunc);

        if (shouldCallFunc) {
          expect(mockFunc).toHaveBeenCalledWith(payload, {});
        } else {
          expect(mockFunc).not.toHaveBeenCalled();
        }
      });
    });
  });

  describe('validateAdditionalProperties', () => {
    it('returns undefined for allowed additional properties', () => {
      const additionalProperties = {
        label: 'value',
        property: 'property',
        value: 123,
      };

      expect(validateAdditionalProperties(additionalProperties)).toBe(undefined);
    });

    it('throws an error if base property has incorrect type', () => {
      const additionalProperties = {
        label: 'value',
        property: 'property',
        value: 'invalidType',
      };

      expect(() => {
        validateAdditionalProperties(additionalProperties);
      }).toThrow('value should be of type: number. Provided type is: string.');
    });

    it('does not throw an error for custom properties', () => {
      const additionalProperties = {
        key: 'value',
      };

      expect(validateAdditionalProperties(additionalProperties)).toBe(undefined);
    });
  });

  describe('validateEvent', () => {
    let sentrySpy;

    beforeEach(() => {
      sentrySpy = jest.spyOn(Sentry, 'captureException');
    });

    afterEach(() => {
      sentrySpy.mockRestore();
    });

    it('calls Sentry for event names with whitespace', () => {
      validateEvent('event name');

      expect(sentrySpy).toHaveBeenCalled();
    });

    it('does not call Sentry for event names eqaual to nil', () => {
      validateEvent(null);

      expect(sentrySpy).not.toHaveBeenCalled();
    });

    it('does not call Sentry for event names without whitespace', () => {
      validateEvent('event-name');

      expect(sentrySpy).not.toHaveBeenCalled();
    });
  });

  describe('getCustomAdditionalProperties', () => {
    it('returns only custom properties', () => {
      const additionalProperties = {
        label: 'value',
        property: 'property',
        value: 123,
        key1: 'value1',
        key2: 2,
      };

      const customProperties = getCustomAdditionalProperties(additionalProperties);

      expect(customProperties).toEqual({
        key1: 'value1',
        key2: 2,
      });
    });
  });

  describe('getBaseAdditionalProperties', () => {
    it('returns only base properties', () => {
      const additionalProperties = {
        label: 'value',
        property: 'property',
        value: 123,
        key1: 'value1',
        key2: 2,
      };

      const baseProperties = getBaseAdditionalProperties(additionalProperties);

      expect(baseProperties).toEqual({
        label: 'value',
        property: 'property',
        value: 123,
      });
    });
  });

  describe('isEventEligible', () => {
    beforeEach(() => {
      window.gl = {};
    });

    it('returns false if action is undefined or empty', () => {
      expect(isEventEligible()).toBe(false);
      expect(isEventEligible('')).toBe(false);
    });

    it.each`
      description                                            | onlySendDuoEvents | duoEvents                            | action                     | expected
      ${'onlySendDuoEvents is false'}                        | ${false}          | ${[]}                                | ${'any-action'}            | ${true}
      ${'onlySendDuoEvents is undefined'}                    | ${undefined}      | ${[]}                                | ${'any-action'}            | ${true}
      ${'action is included in duoEvents when enforced'}     | ${true}           | ${['duo-example-event', 'ai-event']} | ${'duo-example-event'}     | ${true}
      ${'action is included in duoEvents when enforced (2)'} | ${true}           | ${['duo-example-event', 'ai-event']} | ${'ai-event'}              | ${true}
      ${'action is missing in duoEvents when enforced'}      | ${true}           | ${['duo-example-event']}             | ${'non-duo-example-event'} | ${false}
    `(
      'returns $expected when $description',
      ({ onlySendDuoEvents, duoEvents, action, expected }) => {
        window.gl.onlySendDuoEvents = onlySendDuoEvents;
        window.gl.duoEvents = duoEvents;

        expect(isEventEligible(action)).toBe(expected);
      },
    );
  });
});
