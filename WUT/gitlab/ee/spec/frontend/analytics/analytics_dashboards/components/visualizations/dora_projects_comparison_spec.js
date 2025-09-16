import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DoraProjectsComparison from 'ee/analytics/analytics_dashboards/components/visualizations/dora_projects_comparison.vue';
import ComparisonTable from 'ee/analytics/dashboards/dora_projects_comparison/components/comparison_table.vue';
import {
  mockProjectsDoraMetrics,
  mockUnfilteredProjectsDoraMetrics,
} from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';

describe('DoraProjectsComparison Visualization', () => {
  let wrapper;

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMountExtended(DoraProjectsComparison, { propsData });
  };

  const findComparisonTable = () => wrapper.findComponent(ComparisonTable);

  beforeEach(() => {
    createWrapper({
      data: {
        count: mockUnfilteredProjectsDoraMetrics.length,
        projects: mockUnfilteredProjectsDoraMetrics,
      },
    });
  });

  it('renders a tooltip in the panel title', () => {
    expect(wrapper.emitted('showTooltip')[0][0]).toEqual({
      description: 'Showing 2 projects. Excluding 1 project with no DORA metrics.',
    });
  });

  it('filters out projects with empty DORA data', () => {
    expect(findComparisonTable().props().projects).toEqual(mockProjectsDoraMetrics);
  });
});
