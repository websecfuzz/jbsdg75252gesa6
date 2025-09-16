import dateFormat from '~/lib/dateformat';
import { dateFormats } from '~/analytics/shared/constants';

export const formattedDate = (date) => dateFormat(date, dateFormats.defaultDate, true);

export const forecastDataToChartDate = (data, forecast) =>
  [...data.slice(-1), ...forecast].map(({ date, value }) => [formattedDate(date), value]);
