import StageChart from './stage_chart.vue';
import { stageChartData } from './stories_constants';

export default {
  component: StageChart,
  title: 'ee/analytics/cycle_analytics/components/stage_chart',
};

const Template = (args, { argTypes }) => ({
  components: { StageChart },
  props: Object.keys(argTypes),
  template: '<stage-chart v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {
  stageTitle: 'VSA stage',
  isLoading: false,
  plottableData: stageChartData,
};

export const Loading = Template.bind({});
Loading.args = {
  stageTitle: 'VSA stage',
  isLoading: true,
  plottableData: [],
};

export const NoData = Template.bind({});
NoData.args = {
  stageTitle: 'VSA stage',
  isLoading: false,
  plottableData: [],
};

export const ErrorMessage = Template.bind({});
ErrorMessage.args = {
  stageTitle: 'VSA stage',
  isLoading: false,
  plottableData: [],
  errorMessage: 'Failed to load chart',
};
