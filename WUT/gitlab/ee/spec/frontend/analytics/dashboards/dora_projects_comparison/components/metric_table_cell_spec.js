import { DORA_METRICS } from '~/analytics/shared/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrendIndicator from 'ee/analytics/dashboards/components/trend_indicator.vue';
import MetricTableCell from 'ee/analytics/dashboards/dora_projects_comparison/components/metric_table_cell.vue';

describe('Metric table cell', () => {
  let wrapper;

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMountExtended(MetricTableCell, { propsData });
  };

  const findTrendIndicator = () => wrapper.findComponent(TrendIndicator);

  describe.each`
    metricType                              | value       | trend   | formattedValue | invertTrendColor
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}    | ${5}        | ${0.05} | ${'5.0/d'}     | ${false}
    ${DORA_METRICS.LEAD_TIME_FOR_CHANGES}   | ${50000000} | ${0.05} | ${'578.7 d'}   | ${true}
    ${DORA_METRICS.TIME_TO_RESTORE_SERVICE} | ${8000000}  | ${0.05} | ${'92.6 d'}    | ${true}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}     | ${0.1}      | ${0.05} | ${'10.0%'}     | ${true}
  `(
    'for metricType=$metricType',
    ({ metricType, value, trend, formattedValue, invertTrendColor }) => {
      beforeEach(() => {
        createWrapper({ metricType, value, trend });
      });

      it('correctly formats the value', () => {
        expect(wrapper.text()).toBe(formattedValue);
      });

      it('sets the correct color for trend indicator', () => {
        expect(findTrendIndicator().props().invertColor).toBe(invertTrendColor);
      });
    },
  );

  it('hides the trend indicator when trend is zero', () => {
    createWrapper({ metricType: DORA_METRICS.DEPLOYMENT_FREQUENCY, value: 10, trend: 0 });
    expect(findTrendIndicator().exists()).toBe(false);
  });
});
