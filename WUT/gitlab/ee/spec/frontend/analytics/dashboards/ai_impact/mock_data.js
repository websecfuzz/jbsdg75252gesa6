export const mockTimePeriods = [
  {
    key: '5-months-ago',
    label: 'Oct',
    start: new Date('2023-10-01T00:00:00.000Z'),
    end: new Date('2023-10-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 10,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '8.9',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 0,
      tooltip: '0/0',
    },
  },
  {
    key: '4-months-ago',
    label: 'Nov',
    start: new Date('2023-11-01T00:00:00.000Z'),
    end: new Date('2023-11-30T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 15,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '5.6',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 100,
      tooltip: '10/10',
    },
  },
  {
    key: '3-months-ago',
    label: 'Dec',
    start: new Date('2023-12-01T00:00:00.000Z'),
    end: new Date('2024-12-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: null,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '0.0',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 20,
      tooltip: '2/10',
    },
  },
  {
    key: '2-months-ago',
    label: 'Jan',
    start: new Date('2024-01-01T00:00:00.000Z'),
    end: new Date('2024-01-31T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: null,
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 90.9090909090909,
      tooltip: '10/11',
    },
  },
  {
    key: '1-months-ago',
    label: 'Feb',
    start: new Date('2024-02-01T00:00:00.000Z'),
    end: new Date('2024-02-29T23:59:59.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: '-',
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '7.5',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 50,
      tooltip: '5/10',
    },
  },
  {
    key: 'this-month',
    label: 'Mar',
    start: new Date('2024-03-01T00:00:00.000Z'),
    end: new Date('2024-03-15T13:00:00.000Z'),
    thClass: 'gl-w-1/10',
    deployment_frequency: {
      identifier: 'deployment_frequency',
      value: 30,
    },
    change_failure_rate: {
      identifier: 'change_failure_rate',
      value: '4.0',
    },
    code_suggestions_usage_rate: {
      identifier: 'code_suggestions_usage_rate',
      value: 88.88888888888889,
      tooltip: '8/9',
    },
  },
];

export const mockAiMetricsValues = [
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 20,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 10,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 4,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 20,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 10,
  },
  {
    codeSuggestionsContributorsCount: 1,
    codeContributorsCount: 4,
  },
];

const mockTableRow = (
  deploymentFrequency,
  changeFailureRate,
  cycleTime,
  leadTime,
  medianTimeToMerge,
  criticalVulnerabilities,
  [codeSuggestionsContributorsCount, codeContributorsCount],
  [codeSuggestionsAcceptedCount, codeSuggestionsShownCount],
  duoChatContributorsCount,
  rootCauseAnalysisUsersCount,
  duoAssignedUsersCount,
  duoUsedCount,
  // eslint-disable-next-line max-params
) => ({
  deploymentFrequency,
  changeFailureRate,
  cycleTime,
  leadTime,
  medianTimeToMerge,
  criticalVulnerabilities,
  codeSuggestionsContributorsCount,
  codeContributorsCount,
  codeSuggestionsAcceptedCount,
  codeSuggestionsShownCount,
  duoChatContributorsCount,
  rootCauseAnalysisUsersCount,
  duoAssignedUsersCount,
  duoUsedCount,
});

export const mockTableValues = [
  mockTableRow(10, 0.2, 1, 1, 0.1, 40, [1, 20], [3, 15], 3, 5, 15, 100),
  mockTableRow(20, 0.4, 2, 2, 0.2, 20, [1, 10], [3, 7], 3, 6, 7, 100),
  mockTableRow(40, 0.6, 4, 4, 0.3, 10, [1, 4], [10, 15], 10, 11, 15, 100),
  mockTableRow(10, 0.2, 1, 1, 0.3, 40, [1, 20], [9, 18], 9, 12, 18, 100),
  mockTableRow(20, 0.4, 2, 2, 0.2, 20, [1, 10], [3, 17], 3, 7, 17, 100),
  mockTableRow(40, 0.6, 4, 4, 0.1, 10, [1, 4], [4, 12], 4, 6, 12, 100),
];

export const mockTableLargeValues = [
  mockTableRow(10000, 0.1, 4, 0, 10, 4000, [500, 1000], [800, 2000], 800, 1000, 2000, 10000),
  mockTableRow(20000, 0.2, 2, 2, 20, 2000, [1000, 2000], [1000, 1500], 1000, 1200, 1500, 10000),
  mockTableRow(40000, 0.4, 1, 4, 30, 1000, [2500, 5000], [1200, 2400], 1200, 2000, 2400, 10000),
  mockTableRow(10000, 0.1, 4, 1, 30, 4000, [5000, 10000], [2000, 6000], 2000, 4000, 6000, 10000),
  mockTableRow(20000, 0.2, 2, 2, 20, 2000, [1000, 2000], [8000, 9000], 8000, 7000, 9000, 10000),
  mockTableRow(40, 0.4, 1, 4, 10, 5000, [2500, 5000], [7000, 8500], 7000, 8000, 8500, 10000),
];

export const mockTableBlankValues = [
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
  mockTableRow('-', '-', '-', '-', '-', '-', ['-', '-'], ['-', '-'], '-', '-', '-', '-'),
];

export const mockTableZeroValues = [
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
  mockTableRow(0, 0, 0, 0, 0, 0, [0, 0], [0, 0], 0, 0, 0, 0),
];

export const mockTableAndChartValues = [...mockTableValues, ...mockTableValues];

export const mockAiMetricsResponseData = {
  aiMetrics: {
    codeContributorsCount: 8,
    codeSuggestionsContributorsCount: 5,
    codeSuggestionsAcceptedCount: 2,
    codeSuggestionsShownCount: 5,
    duoChatContributorsCount: 5,
    duoAssignedUsersCount: 10,
    duoUsedCount: 3,
    __typename: 'AiMetrics',
  },
  __typename: 'Group',
};

export const mockAiMetricsZeroResponseData = {
  aiMetrics: {
    codeContributorsCount: 0,
    codeSuggestionsContributorsCount: 0,
    codeSuggestionsAcceptedCount: 0,
    codeSuggestionsShownCount: 0,
    duoChatContributorsCount: 0,
    duoAssignedUsersCount: 0,
    duoUsedCount: 0,
    __typename: 'AiMetrics',
  },
  __typename: 'Group',
};

export const mockAiMetricsNullResponseData = {
  aiMetrics: {
    codeContributorsCount: null,
    codeSuggestionsContributorsCount: null,
    codeSuggestionsAcceptedCount: null,
    codeSuggestionsShownCount: null,
    duoChatContributorsCount: null,
    duoAssignedUsersCount: null,
    duoUsedCount: null,
    __typename: 'AiMetrics',
  },
  __typename: 'Group',
};
