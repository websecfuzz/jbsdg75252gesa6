import { nextTick } from 'vue';
import { GlLineChart } from '@gitlab/ui/dist/charts';
import { shallowMount } from '@vue/test-utils';
import OpenVulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';

describe('OpenVulnerabilitiesOverTimeChart', () => {
  let wrapper;

  const firstDayOfChartSeries = '2025-04-17';
  const mockChartSeries = [
    {
      name: 'Critical',
      data: [
        [firstDayOfChartSeries, 5],
        ['2025-04-18', 5],
        ['2025-04-19', 7],
      ],
    },
    {
      name: 'High',
      data: [
        [firstDayOfChartSeries, 25],
        ['2025-04-18', 27],
        ['2025-04-19', 30],
      ],
    },
  ];

  const findLineChart = () => wrapper.findComponent(GlLineChart);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(OpenVulnerabilitiesOverTimeChart, {
      propsData: {
        chartSeries: mockChartSeries,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('passes chart data to GlLineChart via props', () => {
    expect(findLineChart().props('data')).toBe(mockChartSeries);
  });

  it('does not include legend avg/max values', () => {
    expect(findLineChart().props('includeLegendAvgMax')).toBe(false);
  });

  describe('chartOptions', () => {
    it('configures the x-axis correctly', () => {
      expect(findLineChart().props('option').xAxis).toMatchObject({
        name: null,
        key: 'date',
        type: 'category',
      });
    });

    it('configures the y-axis correctly', () => {
      expect(findLineChart().props('option').yAxis).toMatchObject({
        name: null,
        key: 'vulnerabilities',
        type: 'value',
        minInterval: 1,
      });
    });

    it('configures dataZoom with the correct start date when chartStartDate is available', () => {
      expect(findLineChart().props('option').dataZoom[0].startValue).toBe(firstDayOfChartSeries);
    });

    it('does not include dataZoom when chartStartDate is null', async () => {
      createComponent({ chartSeries: [] });
      await nextTick();
      expect(findLineChart().props('option').dataZoom).toBeUndefined();
    });
  });
});
