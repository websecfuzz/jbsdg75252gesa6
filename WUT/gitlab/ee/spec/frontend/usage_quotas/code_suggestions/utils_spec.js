import { DUO_HEALTH_CHECK_CATEGORIES } from 'ee/usage_quotas/code_suggestions/constants';
import { probesByCategory } from 'ee/usage_quotas/code_suggestions/utils';
import {
  MOCK_NETWORK_PROBES,
  MOCK_SYNCHRONIZATION_PROBES,
  MOCK_SYSTEM_EXCHANGE_PROBES,
  MOCK_AI_GATEWAY_PROBES,
  MOCK_CODE_SUGGESTIONS_PROBES,
} from './mock_data';

describe('Code Suggestions Utils', () => {
  describe('probesByCategory', () => {
    it('properly splits up probes into categories', () => {
      const probes = [
        ...MOCK_NETWORK_PROBES.success,
        ...MOCK_SYNCHRONIZATION_PROBES.success,
        ...MOCK_SYSTEM_EXCHANGE_PROBES.success,
      ];

      const expected = probesByCategory(probes);

      expect(expected).toHaveLength(3);
      expect(expected[0]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[1],
        probes: MOCK_NETWORK_PROBES.success,
      });
      expect(expected[1]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[2],
        probes: MOCK_SYNCHRONIZATION_PROBES.success,
      });
      expect(expected[2]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[4],
        probes: MOCK_SYSTEM_EXCHANGE_PROBES.success,
      });
    });

    it('Only output the given probes category', () => {
      const probes = [...MOCK_AI_GATEWAY_PROBES.success, ...MOCK_CODE_SUGGESTIONS_PROBES.success];

      const expected = probesByCategory(probes);

      expect(expected).toHaveLength(2);

      expect(expected[0]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[0],
        probes: MOCK_AI_GATEWAY_PROBES.success,
      });
      expect(expected[1]).toStrictEqual({
        ...DUO_HEALTH_CHECK_CATEGORIES[3],
        probes: MOCK_CODE_SUGGESTIONS_PROBES.success,
      });
    });
  });
});
