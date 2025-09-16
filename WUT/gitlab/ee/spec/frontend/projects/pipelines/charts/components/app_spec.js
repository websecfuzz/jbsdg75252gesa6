import { nextTick } from 'vue';
import { GlTabs, GlTab } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import setWindowLocation from 'helpers/set_window_location_helper';
import { updateHistory } from '~/lib/utils/url_utility';
import App from '~/projects/pipelines/charts/components/app.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import PipelinesDashboard from '~/projects/pipelines/charts/components/pipelines_dashboard.vue';
import DeploymentFrequencyCharts from 'ee_component/analytics/dora/components/deployment_frequency_charts.vue';
import LeadTimeCharts from 'ee_component/analytics/dora/components/lead_time_charts.vue';
import TimeToRestoreServiceCharts from 'ee_component/analytics/dora/components/time_to_restore_service_charts.vue';
import ChangeFailureRateCharts from 'ee_component/analytics/dora/components/change_failure_rate_charts.vue';
import MigrationAlert from 'ee_component/analytics/dora/components/migration_alert.vue';
import ProjectQualitySummaryApp from 'ee_component/project_quality_summary/app.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  updateHistory: jest.fn(),
}));
jest.mock('ee_component/analytics/dora/components/deployment_frequency_charts.vue', () => ({
  name: 'DeploymentFrequencyChartsStub',
  render: () => {},
}));
jest.mock('ee_component/analytics/dora/components/lead_time_charts.vue', () => ({
  name: 'LeadTimeChartsStub',
  render: () => {},
}));
jest.mock('ee_component/analytics/dora/components/time_to_restore_service_charts.vue', () => ({
  name: 'TimeToRestoreServiceChartsStub',
  render: () => {},
}));
jest.mock('ee_component/analytics/dora/components/change_failure_rate_charts.vue', () => ({
  name: 'ChangeFailureRateChartsStub',
  render: () => {},
}));
jest.mock('ee_component/project_quality_summary/app.vue', () => ({
  name: 'ProjectQualitySummaryAppStub',
  render: () => {},
}));

describe('ProjectsPipelinesChartsApp', () => {
  let wrapper;
  let trackEventSpy;

  const projectPath = 'funkys/flightjs';
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createWrapper = ({ provide, ...options } = {}) => {
    wrapper = shallowMount(App, {
      provide: {
        projectPath,
        ...provide,
      },
      ...options,
    });

    trackEventSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
  };

  const findGlTabs = () => wrapper.findComponent(GlTabs);
  const findAllGlTabs = () => wrapper.findAllComponents(GlTab);
  const findGlTabAt = (index) => findAllGlTabs().at(index);

  const findPipelinesDashboard = () => wrapper.findComponent(PipelinesDashboard);

  const findDoraMetricsMigrationAlert = () => wrapper.findComponent(MigrationAlert);
  const findDeploymentFrequencyCharts = () => wrapper.findComponent(DeploymentFrequencyCharts);
  const findLeadTimeCharts = () => wrapper.findComponent(LeadTimeCharts);
  const findTimeToRestoreServiceCharts = () => wrapper.findComponent(TimeToRestoreServiceCharts);
  const findChangeFailureRateCharts = () => wrapper.findComponent(ChangeFailureRateCharts);
  const findProjectQualitySummaryApp = () => wrapper.findComponent(ProjectQualitySummaryApp);

  describe('when dora charts are available', () => {
    describe('when doraMetricsDashboard is disabled', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            shouldRenderDoraCharts: true,
            glFeatures: {
              doraMetricsDashboard: false,
            },
          },
        });
      });

      it('shows 5 tabs', () => {
        expect(findAllGlTabs()).toHaveLength(5);
      });

      it('does not show migration alert', () => {
        expect(findDoraMetricsMigrationAlert().exists()).toBe(false);
      });

      describe('Pipelines tab', () => {
        it(`renders the tab at index 0`, () => {
          expect(findGlTabAt(0).attributes('title')).toBe('Pipelines');
        });

        it(`renders the chart`, () => {
          expect(findPipelinesDashboard().exists()).toBe(true);
        });

        describe('when clicked', () => {
          beforeEach(() => {
            findGlTabAt(0).vm.$emit('click');
          });

          it('records event', () => {
            expect(trackEventSpy).toHaveBeenCalledWith(
              'p_analytics_ci_cd_pipelines',
              {},
              undefined,
            );
          });
        });
      });

      describe.each`
        title                        | finderFn                          | index | event
        ${'Deployment frequency'}    | ${findDeploymentFrequencyCharts}  | ${1}  | ${'p_analytics_ci_cd_deployment_frequency'}
        ${'Lead time'}               | ${findLeadTimeCharts}             | ${2}  | ${'p_analytics_ci_cd_lead_time'}
        ${'Time to restore service'} | ${findTimeToRestoreServiceCharts} | ${3}  | ${'visit_ci_cd_time_to_restore_service_tab'}
        ${'Change failure rate'}     | ${findChangeFailureRateCharts}    | ${4}  | ${'visit_ci_cd_failure_rate_tab'}
      `('"$title" tab', ({ title, finderFn, index, event }) => {
        it(`renders tab with a title ${title} at index ${index}`, () => {
          expect(findGlTabAt(index).attributes('title')).toBe(title);
        });

        it(`renders the ${title} chart`, () => {
          expect(finderFn().exists()).toBe(true);
        });

        describe('when selected', () => {
          beforeEach(async () => {
            findGlTabs().vm.$emit('input', index);
            await nextTick();
          });

          it('updates history', () => {
            expect(updateHistory).toHaveBeenCalledTimes(1);
            expect(updateHistory).toHaveBeenCalledWith(
              expect.objectContaining({
                url: `/?chart=${title.toLowerCase().replace(/\s/g, '-')}`,
              }),
            );
            expect(findGlTabs().attributes('value')).toBe(index.toString());
          });

          it('when selected again, does not update history twice', async () => {
            findGlTabs().vm.$emit('input', index);
            await nextTick();

            expect(updateHistory).toHaveBeenCalledTimes(1);
          });
        });

        describe('when clicked', () => {
          beforeEach(() => {
            findGlTabAt(index).vm.$emit('click');
          });

          it('records event', () => {
            expect(trackEventSpy).toHaveBeenCalledWith(event, {}, undefined);
          });
        });
      });
    });

    describe('when doraMetricsDashboard is enabled', () => {
      beforeEach(() => {
        createWrapper({
          provide: {
            shouldRenderDoraCharts: true,
            glFeatures: {
              doraMetricsDashboard: true,
            },
          },
        });
      });

      it('does not show tabs', () => {
        expect(findGlTabs().exists()).toBe(false);
      });

      it('shows migration alert', () => {
        expect(findDoraMetricsMigrationAlert().props()).toMatchObject({
          namespacePath: projectPath,
          isProject: true,
        });
      });
    });
  });

  describe('when project quality is available', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          shouldRenderQualitySummary: true,
        },
      });
    });

    it('shows 2 tabs', () => {
      expect(findAllGlTabs()).toHaveLength(2);
    });

    it(`renders tab with a title "Project quality" at index 1`, () => {
      expect(findGlTabAt(1).attributes('title')).toBe('Project quality');
    });

    it('renders the project quality summary', () => {
      expect(findProjectQualitySummaryApp().exists()).toBe(true);
    });
  });

  describe('query params', () => {
    describe.each`
      param                        | tab
      ${''}                        | ${'0'}
      ${'fake'}                    | ${'0'}
      ${'pipelines'}               | ${'0'}
      ${'deployment-frequency'}    | ${'1'}
      ${'lead-time'}               | ${'2'}
      ${'time-to-restore-service'} | ${'3'}
      ${'change-failure-rate'}     | ${'4'}
      ${'project-quality'}         | ${'5'}
    `('$chart', ({ param, tab }) => {
      it('shows tab #$tab for URL parameter "$chart"', () => {
        setWindowLocation(`/?chart=${param}`);
        createWrapper({
          provide: {
            shouldRenderDoraCharts: true,
            shouldRenderQualitySummary: true,
          },
        });

        expect(findGlTabs().attributes('value')).toBe(tab);
      });

      it('should set the tab when the back button is clicked', async () => {
        let popstateHandler;

        window.addEventListener = jest.fn();
        window.addEventListener.mockImplementation((event, handler) => {
          if (event === 'popstate') {
            popstateHandler = handler;
          }
        });

        createWrapper({
          provide: {
            shouldRenderDoraCharts: true,
            shouldRenderQualitySummary: true,
          },
        });

        expect(findGlTabs().attributes('value')).toBe('0');

        setWindowLocation(`/?chart=${param}`);
        popstateHandler();
        await nextTick();

        expect(findGlTabs().attributes('value')).toBe(tab);
      });
    });
  });
});
