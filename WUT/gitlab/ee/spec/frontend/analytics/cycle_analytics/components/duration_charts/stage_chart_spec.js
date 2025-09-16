import { GlIcon } from '@gitlab/ui';
import { GlLineChart } from '@gitlab/ui/dist/charts';
import { shallowMount } from '@vue/test-utils';
import { DURATION_STAGE_TIME_DESCRIPTION } from 'ee/analytics/cycle_analytics/constants';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import NoDataAvailableState from 'ee/analytics/cycle_analytics/components/no_data_available_state.vue';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import {
  allowedStages as stages,
  durationChartPlottableData as durationData,
  durationDataSeries,
  durationDataNullSeries,
} from '../../mock_data';

const [selectedStage] = stages;

function createComponent(props = {}) {
  return shallowMount(StageChart, {
    propsData: {
      stageTitle: selectedStage.title,
      isLoading: false,
      plottableData: durationData,
      ...props,
    },
    stubs: {
      ChartSkeletonLoader: true,
    },
  });
}

describe('StageChart', () => {
  let wrapper;

  const findChartDescription = (_wrapper) => _wrapper.findComponent(GlIcon);
  const findStageChart = (_wrapper) => _wrapper.findComponent(GlLineChart);
  const findLoader = (_wrapper) => _wrapper.findComponent(ChartSkeletonLoader);
  const findNoDataAvailableState = (_wrapper) => _wrapper.findComponent(NoDataAvailableState);

  describe('default', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the chart', () => {
      expect(findStageChart(wrapper).exists()).toBe(true);
    });

    it('renders the stage title', () => {
      expect(wrapper.text()).toContain(`Stage time: ${selectedStage.title}`);
    });

    it('sets the chart data', () => {
      expect(findStageChart(wrapper).props('data')).toEqual([
        expect.objectContaining(durationDataSeries),
        durationDataNullSeries,
      ]);
    });

    it('renders the chart description', () => {
      expect(findChartDescription(wrapper).attributes('title')).toBe(
        DURATION_STAGE_TIME_DESCRIPTION,
      );
    });

    describe('with no chart data', () => {
      beforeEach(() => {
        wrapper = createComponent({
          plottableData: [[new Date(), null]],
        });
      });

      it('renders the no data available message', () => {
        expect(findNoDataAvailableState(wrapper).exists()).toBe(true);
      });
    });
  });

  describe('when isLoading=true', () => {
    beforeEach(() => {
      wrapper = createComponent({ isLoading: true });
    });

    it('renders a loader', () => {
      expect(findLoader(wrapper).exists()).toBe(true);
    });
  });
});
