import { formatVulnerabilitiesOverTimeData } from 'ee/security_dashboard/utils/chart_formatters';

describe('chart_formatters', () => {
  describe('formatVulnerabilitiesOverTimeData', () => {
    const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];

    const mockVulnerabilitiesData = [
      {
        date: '2024-01-01',
        bySeverity: [
          { severity: 'CRITICAL', count: 5 },
          { severity: 'HIGH', count: 10 },
          { severity: 'MEDIUM', count: 15 },
        ],
      },
      {
        date: '2024-01-02',
        bySeverity: [
          { severity: 'CRITICAL', count: 3 },
          { severity: 'HIGH', count: 8 },
          { severity: 'LOW', count: 12 },
          { severity: 'INFO', count: 2 },
        ],
      },
      {
        date: '2024-01-03',
        bySeverity: [
          { severity: 'UNKNOWN', count: 1 },
          { severity: 'MEDIUM', count: 7 },
        ],
      },
    ];

    // Returns: [['2024-01-01', 5], ['2024-01-02', 3]] format for chart series
    const getDataPoints = (severity) => {
      return mockVulnerabilitiesData
        .map((day) => {
          const severityData = day.bySeverity.find(
            (s) => s.severity.toUpperCase() === severity.toUpperCase(),
          );
          return severityData ? [day.date, severityData.count] : null;
        })
        .filter(Boolean);
    };
    const findSeriesBySeverity = (name, result) =>
      result.find((series) => series.name === name)?.data;

    it('formats vulnerability data correctly', () => {
      const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData);
      const resultSeriesNames = result.map((series) => series.name);

      expect(resultSeriesNames).toEqual(severities);
    });

    it.each(severities)('includes correct data points for each severity', (severity) => {
      const result = formatVulnerabilitiesOverTimeData(mockVulnerabilitiesData);

      expect(findSeriesBySeverity(severity, result)).toEqual(getDataPoints(severity));
    });

    it.each([[], null, undefined])('returns an empty array when the input is "%s"', (input) => {
      expect(formatVulnerabilitiesOverTimeData(input)).toEqual([]);
    });

    it('handles data with unknown severity levels', () => {
      const dataWithUnknownSeverity = [
        {
          date: '2024-01-01',
          bySeverity: [
            { severity: 'CRITICAL', count: 5 },
            { severity: 'nonexistent', count: 3 },
          ],
        },
      ];

      const result = formatVulnerabilitiesOverTimeData(dataWithUnknownSeverity);
      const criticalSeries = findSeriesBySeverity('Critical', result);

      expect(criticalSeries).toEqual([['2024-01-01', 5]]);

      // Should not create a series for unknown severity
      const nonexistentSeries = findSeriesBySeverity('nonexistent', result);
      expect(nonexistentSeries).toBeUndefined();
    });

    it('handles data with empty bySeverity arrays', () => {
      const dataWithEmptyBySeverity = [
        {
          date: '2024-01-01',
          bySeverity: [],
        },
        {
          date: '2024-01-02',
          bySeverity: [{ severity: 'HIGH', count: 5 }],
        },
      ];

      const result = formatVulnerabilitiesOverTimeData(dataWithEmptyBySeverity);
      const highSeries = result.find((series) => series.name === 'High');

      expect(highSeries.data).toEqual([['2024-01-02', 5]]);
    });

    it('handles zero counts correctly', () => {
      const dataWithZeroCounts = [
        {
          date: '2024-01-01',
          bySeverity: [
            { severity: 'CRITICAL', count: 0 },
            { severity: 'HIGH', count: 5 },
          ],
        },
      ];

      const result = formatVulnerabilitiesOverTimeData(dataWithZeroCounts);
      const criticalSeries = findSeriesBySeverity('Critical', result);
      const highSeries = findSeriesBySeverity('High', result);

      expect(criticalSeries).toEqual([['2024-01-01', 0]]);
      expect(highSeries).toEqual([['2024-01-01', 5]]);
    });
  });
});
