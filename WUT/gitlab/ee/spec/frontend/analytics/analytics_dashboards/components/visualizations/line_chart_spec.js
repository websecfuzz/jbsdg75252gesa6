import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/dist/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LineChart from 'ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue';
import { stubComponent } from 'helpers/stub_component';
import { NULL_SERIES_ID } from 'ee/analytics/shared/constants';
import { UNITS } from '~/analytics/shared/constants';

describe('LineChart Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findLineChart = () => wrapper.findComponent(GlLineChart);
  const findAllChartTooltipItems = () => wrapper.findAllByTestId('chart-tooltip-item');
  const findChartSeriesLabel = (idx = 0) => wrapper.findAllComponents(GlChartSeriesLabel).at(idx);
  const findChartTooltipValue = (idx = 0) => wrapper.findAllByTestId('chart-tooltip-value').at(idx);

  const createWrapper = ({ props = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(LineChart, {
      propsData: {
        data: [],
        options: {},
        ...props,
      },
      stubs,
    });
  };

  describe('when mounted', () => {
    it('should render the line chart with the provided data and option', () => {
      createWrapper({
        props: {
          data: [{ name: 'foo' }],
          options: { yAxis: {}, xAxis: {} },
        },
      });

      expect(findLineChart().props()).toMatchObject({
        data: [{ name: 'foo' }],
        option: { yAxis: {}, xAxis: {} },
        height: 'auto',
      });

      expect(findLineChart().attributes('responsive')).toBe('');
      expect(findLineChart().props().includeLegendAvgMax).toBe(false);
    });

    it('should add minimum y-axis option when not defined', () => {
      createWrapper({
        props: {
          data: [{ name: 'foo' }],
          options: { yAxis: {}, xAxis: {} },
        },
      });

      expect(findLineChart().props().option).toMatchObject({
        yAxis: { min: 0 },
      });
    });

    it('can toggle the average / max values', () => {
      createWrapper({ props: { options: { includeLegendAvgMax: true } } });

      expect(findLineChart().props().includeLegendAvgMax).toBe(true);
    });
  });

  describe('chart tooltip', () => {
    const mockSeries1 = {
      seriesIndex: 0,
      seriesId: 'deployment_frequency',
      seriesName: 'Deployment Frequency',
      value: ['May', 10],
      color: 'red',
    };

    const mockSeries2 = {
      seriesIndex: 1,
      seriesId: 'change_failure_rate',
      seriesName: 'Change Failure Rate',
      value: ['2023-11-12T17:43:11.987', 1],
      color: 'green',
    };

    const mockSeries3 = {
      seriesIndex: 2,
      seriesId: 'time_to_restore_service',
      seriesName: 'Time to restore service',
      value: ['June', 50],
      color: 'yellow',
    };

    const mockSeries4 = {
      seriesIndex: 3,
      seriesId: 'lead_time_for_changes',
      seriesName: 'Lead time for changes',
      value: ['July', 5328],
      color: 'yellow',
    };

    const mockSeries5 = {
      seriesIndex: 4,
      seriesId: 'contributions',
      seriesName: 'Contributions',
      value: ['August', 'No data'],
      color: 'yellow',
    };

    describe('default', () => {
      it.each([mockSeries1, mockSeries2, mockSeries3, mockSeries4, mockSeries5])(
        'should render formatted tooltip',
        (series) => {
          createWrapper({
            stubs: {
              GlLineChart: stubComponent(GlLineChart, {
                data() {
                  const title = series.value.at(0);
                  return { title, params: { seriesData: [series] } };
                },
                template: `<div>
                          <slot name="tooltip-title" :title="title" :params="params"></slot>
                          <slot name="tooltip-content" :params="params"></slot>
                        </div>`,
              }),
            },
          });

          expect(findLineChart().element).toMatchSnapshot();
        },
      );
    });

    describe('with options defined', () => {
      describe('valueUnit', () => {
        it.each`
          series         | valueUnit              | expectedValue
          ${mockSeries1} | ${UNITS.PER_DAY}       | ${'10 /day'}
          ${mockSeries2} | ${UNITS.PERCENT}       | ${'100.0%'}
          ${mockSeries3} | ${UNITS.DAYS}          | ${'50 days'}
          ${mockSeries4} | ${UNITS.TIME_INTERVAL} | ${'1.5 hours'}
        `('should render tooltip with humanized value', ({ series, valueUnit, expectedValue }) => {
          createWrapper({
            props: {
              options: {
                chartTooltip: { valueUnit },
              },
            },
            stubs: {
              GlLineChart: stubComponent(GlLineChart, {
                data() {
                  return { params: { seriesData: [series] } };
                },
                template: `<div>
                          <slot name="tooltip-content" :params="params"></slot>
                        </div>`,
              }),
            },
          });

          expect(findChartTooltipValue().text()).toBe(expectedValue);
        });
      });

      describe('titleFormatter', () => {
        it('should render formatted tooltip title', () => {
          const mockFormatter = (value) => value.toUpperCase();

          createWrapper({
            props: {
              options: {
                chartTooltip: { titleFormatter: mockFormatter },
              },
            },
            stubs: {
              GlLineChart: stubComponent(GlLineChart, {
                data() {
                  return { title: 'May (xAxisName)', params: { seriesData: [mockSeries1] } };
                },
                template: `<div>
                          <slot name="tooltip-title" :title="title" :params="params"></slot>
                        </div>`,
              }),
            },
          });

          expect(wrapper.findByText('MAY').exists()).toBe(true);
        });
      });
    });

    describe('with null series', () => {
      const seriesData = [
        mockSeries1,
        {
          seriesIndex: 1,
          seriesId: NULL_SERIES_ID,
          seriesName: 'No deployments in this period',
          value: ['2023-11-12', 10],
          color: 'gray',
        },
      ];

      it('should not render null series in tooltip', () => {
        createWrapper({
          stubs: {
            GlLineChart: stubComponent(GlLineChart, {
              data() {
                return { params: { seriesData } };
              },
              template: `<div>
                          <slot name="tooltip-content" :params="params"></slot>
                        </div>`,
            }),
          },
        });

        expect(findAllChartTooltipItems()).toHaveLength(1);
        expect(findChartSeriesLabel().text()).toBe('Deployment Frequency');
        expect(findChartTooltipValue().text()).toBe('10');
      });
    });
  });
});
