import { formatNumber } from '~/locale';
import { nSecondsBefore } from '~/lib/utils/datetime_utility';
import { I18N_MEDIAN, I18N_P75, I18N_P90, I18N_P99 } from './constants';

const I18N_PERCENTILES = {
  p99: I18N_P99,
  p90: I18N_P90,
  p75: I18N_P75,
  p50: I18N_MEDIAN,
};

const EMPTY_PLACEHOLDER = '-';

export const formatSeconds = (value) => {
  if (value === null) {
    return EMPTY_PLACEHOLDER;
  }
  return formatNumber(value, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const emptyWaitTimeQueryData = {
  p50: null,
  p75: null,
  p90: null,
  p99: null,
};

export const runnerWaitTimeQueryData = (queryData) => {
  const { __typename, ...durations } = queryData || emptyWaitTimeQueryData;
  return Object.entries(durations).map(([key, value]) => ({
    key,
    title: I18N_PERCENTILES[key] || key,
    value: formatSeconds(value),
  }));
};

export const runnerWaitTimeHistoryQueryData = (queryData = []) => {
  const result = {};

  queryData.forEach((point) => {
    const { __typename, time, ...durations } = point;

    Object.entries(durations).forEach(([key, value]) => {
      result[key] = result[key] || [];
      result[key].push([time, value]);
    });
  });

  return Object.entries(result).map(([key, data]) => ({
    name: I18N_PERCENTILES[key] || key,
    data,
  }));
};

const THREE_HOURS_SECS = 60 * 60 * 3;

/**
 * Returns the time range variables for a history query.
 *
 * Defaults to 3 hours.
 */
export const runnerWaitTimeHistoryRange = (seconds = THREE_HOURS_SECS) => {
  const now = new Date();

  return {
    fromTime: nSecondsBefore(now, seconds).toISOString(),
    toTime: now.toISOString(),
  };
};
