import { GlButton, GlLink, GlSprintf, GlDashboardPanel } from '@gitlab/ui';
import { nextTick } from 'vue';
import { VARIANT_DANGER, VARIANT_WARNING, VARIANT_INFO } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import LineChart from 'ee/analytics/analytics_dashboards/components/visualizations/line_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import waitForPromises from 'helpers/wait_for_promises';
import AnalyticsDashboardPanel from 'ee/analytics/analytics_dashboards/components/analytics_dashboard_panel.vue';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { mockPanel, invalidVisualization, licensedVisualization } from '../mock_data';

const mockFetch = jest.fn().mockResolvedValue([]);
jest.mock('ee/analytics/analytics_dashboards/data_sources', () => ({
  cube_analytics: jest.fn().mockImplementation(() => Promise.resolve({ default: mockFetch })),
}));

describe('AnalyticsDashboardPanel', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findPanelRetryButton = () => wrapper.findComponent(GlButton);
  const findAlertMessages = () => wrapper.findByTestId('alert-messages').findAll('li');
  const findAlertDescriptionLink = () => wrapper.findComponent(GlLink);
  const findAlertBody = () => wrapper.findByTestId('alert-body');
  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findDashboardPanelLicenseWarning = () =>
    wrapper.findByTestId('dashboard-panel-license-warning');
  const findVisualization = () => wrapper.findComponent(LineChart);

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AnalyticsDashboardPanel, {
      provide: {
        namespaceId: '1',
        namespaceName: 'Namespace name',
        namespaceFullPath: 'namespace/full/path',
        rootNamespaceName: 'MEOW',
        rootNamespaceFullPath: 'namespace',
        isProject: true,
        dataSourceClickhouse: true,
        overviewCountsAggregationEnabled: true,
        licensedFeatures: {
          hasDoraMetrics: true,
        },
        ...provide,
      },
      propsData: {
        title: mockPanel.title,
        visualization: mockPanel.visualization,
        queryOverrides: mockPanel.queryOverrides,
        ...props,
      },
      stubs: {
        ExtendedDashboardPanel,
        GlSprintf,
        LineChart,
      },
    });
  };

  afterEach(() => mockFetch.mockReset());

  const expectPanelLoaded = () => {
    expect(findExtendedDashboardPanel().props()).toMatchObject({
      loading: false,
      showAlertState: false,
    });
  };

  const expectPanelErrored = () => {
    expect(findExtendedDashboardPanel().props()).toMatchObject({
      loading: false,
      showAlertState: true,
      alertPopoverTitle: 'Failed to fetch data',
    });
  };

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the panel base component', () => {
      expect(findExtendedDashboardPanel().props()).toMatchObject({
        title: mockPanel.title,
        tooltip: null,
        loading: true,
        showAlertState: false,
        alertPopoverTitle: '',
        actions: [
          {
            text: 'Delete',
            action: expect.any(Function),
            icon: 'remove',
          },
        ],
        editing: false,
      });
    });

    it('fetches from the data source with the proper parameters', () => {
      expect(mockFetch).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Daily Active Users',
          projectId: '1',
          namespace: 'namespace/full/path',
          isProject: true,
          query: mockPanel.visualization.data.query,
          queryOverrides: mockPanel.queryOverrides,
          visualizationType: mockPanel.visualization.type,
          visualizationOptions: mockPanel.visualization.options,
          filters: {},
          dataSourceClickhouse: true,
          overviewCountsAggregationEnabled: true,
          setAlerts: expect.any(Function),
          onRequestDelayed: expect.any(Function),
          setVisualizationOverrides: expect.any(Function),
        }),
      );
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createWrapper({
        props: { editing: true },
      });
    });

    it('sets editing to true on the panels base', () => {
      expect(findExtendedDashboardPanel().props()).toMatchObject({
        editing: true,
      });
    });
  });

  describe('when the visualization is licensed invalid', () => {
    describe('with the correct license', () => {
      it('renders the visualization', () => {
        createWrapper({
          props: { visualization: licensedVisualization },
        });

        expect(findDashboardPanelLicenseWarning().exists()).toBe(false);
      });
    });

    describe('without the correct license', () => {
      beforeEach(() => {
        createWrapper({
          props: { visualization: licensedVisualization },
          provide: {
            licensedFeatures: {
              hasDoraMetrics: false,
            },
          },
        });
      });

      it('renders the panel permissions state', () => {
        expect(findDashboardPanel().props('titleIconClass')).toBe('gl-text-danger');
        expect(findDashboardPanel().props('borderColorClass')).toBe('gl-border-t-red-500');
        expect(findDashboardPanel().props('bodyContentClass')).toBe('gl-content-center');
      });

      it('renders the missing license message', () => {
        expect(findDashboardPanelLicenseWarning().text()).toBe(
          'This feature requires an Ultimate plan Learn more.',
        );
      });
    });
  });

  describe('when the visualization configuration is invalid', () => {
    beforeEach(() => {
      createWrapper({
        props: { visualization: invalidVisualization },
      });
    });

    it('sets the error state on the panels base component', () => {
      expect(findExtendedDashboardPanel().props()).toMatchObject({
        loading: false,
        showAlertState: true,
        alertPopoverTitle: 'Invalid visualization configuration',
      });
    });

    it('renders the bad configuration error message', () => {
      expect(wrapper.text()).toContain(
        'Something is wrong with your panel visualization configuration.',
      );
    });

    it('does not render a retry button', () => {
      expect(findPanelRetryButton().exists()).toBe(false);
    });

    it('renders the error messages', () => {
      const errors = findAlertMessages();

      expect(errors).toHaveLength(2);
      expect(errors.at(0).text()).toContain("property '/version' is not: 1");
      expect(errors.at(1).text()).toContain(
        "property '/titlePropertyTypoOhNo' is invalid: error_type=schema",
      );
    });

    it('renders a link to the help docs', () => {
      expect(findAlertDescriptionLink().attributes('href')).toBe(
        '/help/user/analytics/analytics_dashboards#troubleshooting',
      );
    });
  });

  describe('when fetching the data', () => {
    it('sets the loading state on the panels base component', async () => {
      mockFetch.mockReturnValue(new Promise(() => {}));
      createWrapper();
      await waitForPromises();

      expect(findExtendedDashboardPanel().props()).toMatchObject({
        loading: true,
        loadingDelayed: false,
        showAlertState: false,
      });
    });

    it('sets the loadingDelayed state on the panels base component if the data source is slow', async () => {
      mockFetch.mockImplementation(({ onRequestDelayed }) => onRequestDelayed());
      createWrapper();

      await nextTick();
      await nextTick();

      expect(findExtendedDashboardPanel().props()).toMatchObject({
        loading: true,
        loadingDelayed: true,
        showAlertState: false,
      });
    });
  });

  describe('when the data has been fetched', () => {
    describe('and there is data', () => {
      const mockData = [{ name: 'foo' }];

      beforeEach(() => {
        mockFetch.mockResolvedValue(mockData);
        createWrapper();
        return waitForPromises();
      });

      it('loaded the panel', () => {
        expectPanelLoaded();
      });

      it('renders the visualization with the fetched data', () => {
        expect(findVisualization().props()).toMatchObject({
          data: mockData,
          options: mockPanel.visualization.options,
        });
      });

      describe('and the visualization emits showTooltip', () => {
        const tooltip = { description: 'This is a tooltip' };

        beforeEach(() => {
          findVisualization().vm.$emit('showTooltip', tooltip);
        });

        it('sets the tooltip on the panels base component', () => {
          expect(findExtendedDashboardPanel().props('tooltip')).toBe(tooltip);
        });

        describe('and the visualization emits an error', () => {
          const error = 'test error';
          let captureExceptionSpy;

          beforeEach(() => {
            captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          });

          afterEach(() => {
            captureExceptionSpy.mockRestore();
          });

          describe('with errors', () => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-alerts', {
                errors: [error],
                warnings: [error],
                alerts: [error],
                canRetry: false,
              });
            });

            it('sets the error state on the panels base component', () => {
              expect(findExtendedDashboardPanel().props()).toMatchObject({
                loading: false,
                showAlertState: true,
                alertVariant: VARIANT_DANGER,
              });
            });

            it('hides the visualization', () => {
              expect(findVisualization().exists()).toBe(false);
            });

            it('shows the default error body', () => {
              expect(findAlertBody().text()).toBe('Something went wrong.');
            });

            it('logs the error to Sentry', () => {
              expect(captureExceptionSpy).toHaveBeenCalledWith(error);
            });
          });

          describe('with warnings', () => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-alerts', {
                warnings: [error],
                alerts: [error],
                canRetry: false,
              });
            });

            it('sets the error state on the panels base component', () => {
              expect(findExtendedDashboardPanel().props()).toMatchObject({
                loading: false,
                showAlertState: true,
                alertVariant: VARIANT_WARNING,
              });
            });

            it('shows visualization', () => {
              expect(findVisualization().exists()).toBe(true);
            });

            it('does not show the error body', () => {
              expect(findAlertBody().exists()).toBe(false);
            });

            it('does not log to Sentry', () => {
              expect(captureExceptionSpy).not.toHaveBeenCalled();
            });
          });

          describe('with alerts', () => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-alerts', {
                alerts: [error],
                canRetry: false,
              });
            });

            it('sets the alert state on the panels base component', () => {
              expect(findExtendedDashboardPanel().props()).toMatchObject({
                loading: false,
                showAlertState: true,
                alertVariant: VARIANT_INFO,
              });
            });

            it('shows visualization', () => {
              expect(findVisualization().exists()).toBe(true);
            });

            it('does not show the error body', () => {
              expect(findAlertBody().exists()).toBe(false);
            });

            it('does not log to Sentry', () => {
              expect(captureExceptionSpy).not.toHaveBeenCalled();
            });
          });

          describe('with only alert description', () => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-alerts', {
                description: 'This is just information',
              });
            });

            it('sets the alert state on the panels base component', () => {
              expect(findExtendedDashboardPanel().props()).toMatchObject({
                loading: false,
                showAlertState: true,
                alertVariant: VARIANT_INFO,
              });
            });

            it('shows visualization', () => {
              expect(findVisualization().exists()).toBe(true);
            });

            it('does not show the error body', () => {
              expect(findAlertBody().exists()).toBe(false);
            });

            it('does not log to Sentry', () => {
              expect(captureExceptionSpy).not.toHaveBeenCalled();
            });
          });

          describe('with an alert description containing link placeholders', () => {
            it('sets the default if there is no set', async () => {
              findVisualization().vm.$emit('set-alerts', {
                description: 'This is just information, %{linkStart}learn more%{linkEnd}',
              });

              await nextTick();

              expect(findAlertDescriptionLink().attributes('href')).toBe(
                '/help/user/analytics/analytics_dashboards#troubleshooting',
              );
            });

            it('can override the default link', async () => {
              findVisualization().vm.$emit('set-alerts', {
                description: 'This is just information, %{linkStart}learn more%{linkEnd}',
                descriptionLink: 'https://en.wikipedia.org/wiki/Macross_Plus',
              });

              await nextTick();

              expect(findAlertDescriptionLink().attributes('href')).toBe(
                'https://en.wikipedia.org/wiki/Macross_Plus',
              );
            });
          });

          describe.each`
            canRetry
            ${false}
            ${true}
          `('canRetry: $canRetry', ({ canRetry }) => {
            beforeEach(() => {
              findVisualization().vm.$emit('set-alerts', { errors: [error], canRetry });
            });

            it(`${canRetry ? 'renders' : 'does not render'} a retry button`, () => {
              expect(findPanelRetryButton().exists()).toBe(canRetry);
            });
          });
        });
      });

      describe('updateQuery', () => {
        it('refetches data with the overrides sent from the updateQuery event', async () => {
          findVisualization().vm.$emit('updateQuery', { foo: 'bar' });

          await waitForPromises();

          expect(mockFetch).toHaveBeenCalledTimes(2);

          expect(mockFetch).toHaveBeenCalledWith(
            expect.objectContaining({
              queryOverrides: { ...mockPanel.queryOverrides, foo: 'bar' },
            }),
          );
        });
      });
    });

    describe('and the result is empty', () => {
      beforeEach(() => {
        mockFetch.mockResolvedValue(undefined);
        createWrapper();
        return waitForPromises();
      });

      it('loaded the panel', () => {
        expectPanelLoaded();
      });

      it('renders the empty state', () => {
        const text = wrapper.text();
        expect(text).toContain('No results match your query or filter.');
      });
    });

    describe('and there is a generic data source error', () => {
      let captureExceptionSpy;
      const mockGenericError = new Error('foo');

      beforeEach(() => {
        captureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        mockFetch.mockRejectedValue(mockGenericError);

        createWrapper();

        return waitForPromises();
      });

      afterEach(() => {
        captureExceptionSpy.mockRestore();
      });

      it('sets the error state on the panels base component', () => {
        expectPanelErrored();
      });

      it('logs the error to Sentry', () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(mockGenericError);
      });

      it('renders a retry button', () => {
        expect(findPanelRetryButton().text()).toBe('Retry');
      });

      it('refetches the visualization data when the retry button is clicked', async () => {
        findPanelRetryButton().vm.$emit('click');

        await waitForPromises();

        expect(mockFetch).toHaveBeenCalledTimes(2);
      });

      it('renders the data source connection error message', () => {
        expect(wrapper.text()).toContain(
          'Something went wrong while connecting to your data source.',
        );
      });
    });

    describe('and there is a "Bad Request" data source error', () => {
      const mockBadRequestError = new Error('Bad Request');
      mockBadRequestError.status = HTTP_STATUS_BAD_REQUEST;
      mockBadRequestError.response = {
        message: 'Some specific CubeJS error',
      };

      beforeEach(() => {
        mockFetch.mockRejectedValue(mockBadRequestError);

        createWrapper();

        return waitForPromises();
      });

      it('sets the error state on the panels base component', () => {
        expectPanelErrored();
      });

      it('renders a popover message with details of the bad request', () => {
        const messages = findAlertMessages();

        expect(messages).toHaveLength(1);
        expect(messages.at(0).text()).toBe('Some specific CubeJS error');
      });

      it('does not render the retry button', () => {
        expect(findPanelRetryButton().exists()).toBe(false);
      });
    });

    describe('setVisualizationOverrides callback', () => {
      const optionsClone = cloneWithoutReferences(mockPanel.visualization.options);
      const visualizationOptionOverrides = { description: 'found 10 items' };

      beforeEach(() => {
        mockFetch.mockImplementation(({ setVisualizationOverrides }) => {
          setVisualizationOverrides({ visualizationOptionOverrides });
          return Promise.resolve([{ name: 'foo' }]);
        });

        createWrapper();
        return waitForPromises();
      });

      it('can update visualizationOptions', () => {
        expect(findVisualization().props('options')).toStrictEqual({
          xAxis: { name: 'Time', type: 'time' },
          yAxis: { name: 'Counts', type: 'time' },
          description: 'found 10 items',
        });
      });

      it('does not modify the original visualization options', () => {
        expect(mockPanel.visualization.options).toStrictEqual(optionsClone);
      });
    });
  });

  describe('when multiple requests are made', () => {
    let requests;

    beforeEach(() => {
      requests = [];
      mockFetch.mockImplementation(
        () =>
          new Promise((resolve) => {
            requests.push(resolve);
          }),
      );
      createWrapper();
    });

    it('only assigns data for the most recent request', async () => {
      const initialRequestData = [{ name: 'initial' }];
      const firstRequestData = [{ name: 'first' }];
      const secondRequestData = [{ name: 'second' }];

      requests[0](initialRequestData);
      await waitForPromises();

      // trigger 2x subsequent requests by filtering
      wrapper.setProps({ filters: { startDate: new Date() } });
      await nextTick();
      wrapper.setProps({ filters: { startDate: new Date() } });
      await nextTick();

      await waitForPromises();

      // resolve the requests out of order
      requests[2](secondRequestData);
      await nextTick();
      requests[1](firstRequestData);
      await nextTick();

      expect(findVisualization().props('data')).toBe(secondRequestData);
    });
  });

  describe('when fetching data with filters', () => {
    const filters = {
      dateRange: {
        startDate: new Date('2015-01-01'),
        endDate: new Date('2016-01-01'),
      },
    };

    beforeEach(() => {
      mockFetch.mockReturnValue(new Promise(() => {}));
      createWrapper({ props: { filters } });
      return waitForPromises();
    });

    it('fetches from the data source with filters', () => {
      expect(mockFetch).toHaveBeenCalledWith(expect.objectContaining({ filters }));
    });
  });

  describe('title interpolation', () => {
    it.each`
      inputTitle                              | renderedTitle
      ${'title for %{namespaceName}'}         | ${'title for Namespace name'}
      ${'title for %{namespaceFullPath}'}     | ${'title for namespace/full/path'}
      ${'title for %{rootNamespaceName}'}     | ${'title for MEOW'}
      ${'title for %{rootNamespaceFullPath}'} | ${'title for namespace'}
    `('renders $renderedTitle for $inputTitle', ({ inputTitle, renderedTitle }) => {
      createWrapper({ props: { title: inputTitle } });
      expect(findExtendedDashboardPanel().props('title')).toBe(renderedTitle);
    });

    it.each`
      isProject | renderedTitle
      ${true}   | ${'title for project'}
      ${false}  | ${'title for group'}
    `(
      'renders $renderedTitle for namespaceType when isProject is $isProject',
      ({ isProject, renderedTitle }) => {
        createWrapper({ props: { title: 'title for %{namespaceType}' }, provide: { isProject } });
        expect(findExtendedDashboardPanel().props('title')).toBe(renderedTitle);
      },
    );
  });
});
