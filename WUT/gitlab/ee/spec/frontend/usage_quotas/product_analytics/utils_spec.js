import { projectHasProductAnalyticsEnabled } from 'ee/usage_quotas/product_analytics/utils';
import { getProjectUsage } from './graphql/mock_data';

describe('Product analytics usage quota utils', () => {
  describe('projectHasProductAnalyticsEnabled', () => {
    it.each`
      count   | expected
      ${null} | ${false}
      ${0}    | ${true}
      ${1}    | ${true}
    `('returns $expected when events stored count is $count', ({ count, expected }) => {
      const result = projectHasProductAnalyticsEnabled(
        getProjectUsage({ id: 1, name: 'some project', usage: [{ year: 2023, month: 11, count }] }),
      );
      expect(result).toBe(expected);
    });
  });
});
