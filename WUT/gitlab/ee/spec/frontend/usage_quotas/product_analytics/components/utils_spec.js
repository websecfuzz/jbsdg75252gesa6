import {
  projectsUsageDataValidator,
  findCurrentMonthUsage,
  findPreviousMonthUsage,
  mapMonthlyTotals,
  monthlyTotalsValidator,
} from 'ee/usage_quotas/product_analytics/components/utils';
import {
  getProjectUsage,
  getProjectWithYearsUsage,
} from 'ee_jest/usage_quotas/product_analytics/graphql/mock_data';
import { useFakeDate } from 'helpers/fake_date';

describe('Product analytics usage quota component utils', () => {
  describe('projectsUsageDataValidator', () => {
    let validProject;

    beforeEach(() => {
      validProject = getProjectUsage({
        id: 'gid://gitlab/Project/2',
        name: 'another project',
        usage: [
          {
            year: 2023,
            month: 11,
            count: null,
          },
        ],
      });
    });

    it('returns true for empty array', () => {
      const result = projectsUsageDataValidator([]);

      expect(result).toBe(true);
    });

    it('returns true when all items have all properties', () => {
      const result = projectsUsageDataValidator([validProject, getProjectUsage()]);

      expect(result).toBe(true);
    });

    it('returns false when given null', () => {
      const result = projectsUsageDataValidator(null);

      expect(result).toBe(false);
    });

    it('returns false when one item is invalid', () => {
      const result = projectsUsageDataValidator([
        validProject,
        {
          ...validProject,
          name: undefined,
        },
      ]);

      expect(result).toBe(false);
    });

    it.each([
      {
        ...validProject,
        id: undefined,
      },
      {
        ...validProject,
        name: undefined,
      },
      {
        ...validProject,
        productAnalyticsEventsStored: undefined,
      },
      {
        ...validProject,
        webUrl: undefined,
      },
      {
        ...validProject,
        avatarUrl: undefined,
      },
    ])('returns false when an item property is missing', (testCase) => {
      const result = projectsUsageDataValidator([testCase]);

      expect(result).toBe(false);
    });

    it.each([
      {
        ...validProject,
        id: false,
      },
      {
        ...validProject,
        name: false,
      },
      {
        ...validProject,
        productAnalyticsEventsStored: false,
      },
      {
        ...validProject,
        webUrl: false,
      },
      {
        ...validProject,
        avatarUrl: false,
      },
    ])('returns false when an item property is the wrong type', (testCase) => {
      const result = projectsUsageDataValidator([testCase]);

      expect(result).toBe(false);
    });
  });

  describe('monthlyTotalsValidator', () => {
    it('should return true for a valid array of monthly totals', () => {
      const items = [
        ['Nov 2023', 10],
        ['Dec 2023', 12],
        ['Jan 2024', 15],
      ];

      const isValid = monthlyTotalsValidator(items);

      expect(isValid).toBe(true);
    });

    it('should return false if not given an array of arrays', () => {
      const items = ['Nov 2023', 10];

      const isValid = monthlyTotalsValidator(items);

      expect(isValid).toBe(false);
    });

    it('should return false for an array that contains an invalid date label', () => {
      const items = [
        [false, 10],
        ['12 2023', 12],
        ['Jan 2024', 15],
      ];

      const isValid = monthlyTotalsValidator(items);

      expect(isValid).toBe(false);
    });

    it('should return false for an array that contains an invalid count', () => {
      const items = [
        ['Nov 2023', 10],
        ['Dec 2023', '12'],
        ['Jan 2024', 15],
      ];

      const isValid = monthlyTotalsValidator(items);

      expect(isValid).toBe(false);
    });
  });

  describe('findCurrentMonthUsage', () => {
    const mockNow = '2023-01-15T12:00:00Z';
    useFakeDate(mockNow);

    it('returns the expected usage', () => {
      const result = findCurrentMonthUsage(getProjectWithYearsUsage());

      expect(result).toMatchObject({
        count: 1,
        month: 1,
        year: 2023,
      });
    });
  });

  describe('findPreviousMonthUsage', () => {
    const mockNow = '2023-01-15T12:00:00Z';
    useFakeDate(mockNow);

    it('returns the expected usage', () => {
      const result = findPreviousMonthUsage(getProjectWithYearsUsage());

      expect(result).toMatchObject({
        count: 1,
        month: 12,
        year: 2022,
      });
    });
  });

  describe('mapMonthlyTotals', () => {
    it('returns an empty array for empty projects array', () => {
      const result = mapMonthlyTotals([]);
      expect(result).toEqual([]);
    });

    it('sums counts for the same month and year', () => {
      const projects = [
        getProjectUsage({ usage: [{ year: 2023, month: 1, count: 10 }] }),
        getProjectUsage({ usage: [{ year: 2023, month: 1, count: 5 }] }),
      ];
      const result = mapMonthlyTotals(projects);
      expect(result).toEqual([['Jan 2023', 15]]);
    });

    it('handles multiple months and years', () => {
      const projects = [
        getProjectUsage({ usage: [{ year: 2023, month: 1, count: 10 }] }),
        getProjectUsage({ usage: [{ year: 2022, month: 12, count: 5 }] }),
        getProjectUsage({ usage: [{ year: 2023, month: 2, count: 8 }] }),
      ];
      const result = mapMonthlyTotals(projects);
      expect(result).toEqual([
        ['Dec 2022', 5],
        ['Jan 2023', 10],
        ['Feb 2023', 8],
      ]);
    });

    it('returns sorted results', () => {
      const projects = [
        getProjectUsage({ usage: [{ year: 2023, month: 2, count: 8 }] }),
        getProjectUsage({ usage: [{ year: 2023, month: 1, count: 10 }] }),
        getProjectUsage({ usage: [{ year: 2022, month: 12, count: 5 }] }),
      ];
      const result = mapMonthlyTotals(projects);
      expect(result).toEqual([
        ['Dec 2022', 5],
        ['Jan 2023', 10],
        ['Feb 2023', 8],
      ]);
    });

    it('handles empty months', () => {
      const projects = [
        getProjectUsage({ usage: [{ year: 2023, month: 1, count: 0 }] }),
        getProjectUsage({ usage: [{ year: 2023, month: 2, count: 0 }] }),
      ];
      const result = mapMonthlyTotals(projects);
      expect(result).toEqual([
        ['Jan 2023', 0],
        ['Feb 2023', 0],
      ]);
    });
  });
});
