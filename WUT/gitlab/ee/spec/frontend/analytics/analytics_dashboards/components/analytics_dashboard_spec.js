import { GlSkeletonLoader, GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  HTTP_STATUS_CREATED,
  HTTP_STATUS_FORBIDDEN,
  HTTP_STATUS_BAD_REQUEST,
} from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import getAvailableVisualizations from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_visualizations.query.graphql';
import AnalyticsDashboard from 'ee/analytics/analytics_dashboards/components/analytics_dashboard.vue';
import AnalyticsDashboardPanel from 'ee/analytics/analytics_dashboards/components/analytics_dashboard_panel.vue';
import CustomizableDashboard from '~/vue_shared/components/customizable_dashboard/customizable_dashboard.vue';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import ValueStreamFeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';
import { updateApolloCache } from 'ee/analytics/analytics_dashboards/utils';
import UsageOverviewBackgroundAggregationWarning from 'ee/analytics/dashboards/components/usage_overview_background_aggregation_warning.vue';
import {
  DATE_RANGE_OPTION_TODAY,
  DATE_RANGE_OPTION_CUSTOM,
  DATE_RANGE_OPTION_LAST_7_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  buildDefaultDashboardFilters,
  filtersToQueryParams,
} from 'ee/analytics/analytics_dashboards/components/filters/utils';
import AnonUsersFilter from 'ee/analytics/analytics_dashboards/components/filters/anon_users_filter.vue';
import DateRangeFilter from 'ee/analytics/analytics_dashboards/components/filters/date_range_filter.vue';
import ProjectsFilter from 'ee/analytics/analytics_dashboards/components/filters/projects_filter.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  NEW_DASHBOARD,
  EVENT_LABEL_CREATED_DASHBOARD,
  EVENT_LABEL_EDITED_DASHBOARD,
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_VIEWED_DASHBOARD,
  CUSTOM_VALUE_STREAM_DASHBOARD,
} from 'ee/analytics/analytics_dashboards/constants';
import { saveCustomDashboard } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import {
  dashboard,
  TEST_EMPTY_DASHBOARD_SVG_PATH,
} from 'jest/vue_shared/components/customizable_dashboard/mock_data';
import { stubComponent } from 'helpers/stub_component';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import UrlSync, {
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
} from '~/vue_shared/components/url_sync.vue';
import FilteredSearchFilter from 'ee/analytics/analytics_dashboards/components/filters/filtered_search_filter.vue';
import {
  TEST_CUSTOM_DASHBOARDS_GROUP,
  TEST_ROUTER_BACK_HREF,
  TEST_DASHBOARD_GRAPHQL_404_RESPONSE,
  TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  createDashboardGraphqlSuccessResponse,
  createGroupDashboardGraphqlSuccessResponse,
  TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  mockInvalidDashboardErrors,
  TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE,
  getGraphQLDashboardWithPanels,
  mockDateRangeFilterChangePayload,
  mockFilteredSearchChangePayload,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api', () => ({
  saveCustomDashboard: jest.fn(),
}));

jest.mock('ee/analytics/analytics_dashboards/utils');

const showToast = jest.fn();

Vue.use(VueApollo);

describe('AnalyticsDashboard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const namespaceId = '1';

  const findDashboard = () => wrapper.findComponent(CustomizableDashboard);
  const findAllPanels = () => wrapper.findAllComponents(AnalyticsDashboardPanel);
  const findPanelByTitle = (title) =>
    findAllPanels().wrappers.find((w) => w.props('title') === title);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findProductAnalyticsFeedbackBanner = () =>
    wrapper.findComponent(ProductAnalyticsFeedbackBanner);
  const findValueStreamFeedbackBanner = () => wrapper.findComponent(ValueStreamFeedbackBanner);
  const findInvalidDashboardAlert = () =>
    wrapper.findByTestId('analytics-dashboard-invalid-config-alert');
  const findUsageOverviewAggregationWarning = () =>
    wrapper.findComponent(UsageOverviewBackgroundAggregationWarning);
  const findAfterDescriptionLink = () => wrapper.findByTestId('after-description-link');
  const findAnonUsersFilter = () => wrapper.findComponent(AnonUsersFilter);
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findProjectsFilter = () => wrapper.findComponent(ProjectsFilter);
  const findFilteredSearchFilter = () => wrapper.findComponent(FilteredSearchFilter);
  const findUrlSync = () => wrapper.findComponent(UrlSync);

  const mockSaveDashboardImplementation = async (responseCallback, dashboardToSave = dashboard) => {
    saveCustomDashboard.mockImplementation(responseCallback);

    await waitForPromises();

    findDashboard().vm.$emit('save', dashboardToSave.slug, dashboardToSave);
  };

  const getFirstParsedDashboard = (dashboards) => {
    const firstDashboard = dashboards.data.project.customizableDashboards.nodes[0];

    const panels = firstDashboard.panels?.nodes || [];

    return {
      ...firstDashboard,
      panels,
    };
  };

  const mockCustomizableDashboardDeletePanel = jest.fn();

  let mockAnalyticsDashboardsHandler = jest.fn();
  let mockAvailableVisualizationsHandler = jest.fn();

  const mockDashboardResponse = (response) => {
    mockAnalyticsDashboardsHandler = jest.fn().mockResolvedValue(response);
  };
  const mockAvailableVisualizationsResponse = (response) => {
    mockAvailableVisualizationsHandler = jest.fn().mockResolvedValue(response);
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler = jest.fn();
    mockAvailableVisualizationsHandler = jest.fn();
    mockCustomizableDashboardDeletePanel.mockRestore();
  });

  const breadcrumbState = { updateName: jest.fn() };

  const mockNamespace = {
    namespaceId,
    namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
  };

  const createWrapper = ({
    props = {},
    routeSlug = '',
    provide = {},
    stubMockMethods = {},
  } = {}) => {
    const mocks = {
      $toast: {
        show: showToast,
      },
      $route: {
        params: {
          slug: routeSlug,
        },
      },
      $router: {
        replace() {},
        push() {},
        resolve: () => ({ href: TEST_ROUTER_BACK_HREF }),
      },
    };

    const mockApollo = createMockApollo([
      [getCustomizableDashboardQuery, mockAnalyticsDashboardsHandler],
      [getAvailableVisualizations, mockAvailableVisualizationsHandler],
    ]);

    wrapper = shallowMountExtended(AnalyticsDashboard, {
      apolloProvider: mockApollo,
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
        GlLink,
        AnonUsersFilter,
        DateRangeFilter,
        FilteredSearchFilter,
        RouterLink: true,
        RouterView: true,
        ProjectsFilter,
        CustomizableDashboard: stubComponent(CustomizableDashboard, {
          methods: {
            ...stubMockMethods,
            deletePanel: mockCustomizableDashboardDeletePanel,
          },
          template: `<div>
            <slot name="alert"></slot>
            <slot name="after-description"></slot>
            <slot name="filters"></slot>
            <template v-for="panel in initialDashboard.panels">
              <slot name="panel" v-bind="{ panel, deletePanel, editing: false }"></slot>
            </template>
          </div>`,
        }),
      },
      mocks,
      provide: {
        ...mockNamespace,
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
        dashboardEmptyStateIllustrationPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        breadcrumbState,
        isGroup: false,
        isProject: true,
        overviewCountsAggregationEnabled: true,
        customizableDashboardsAvailable: true,
        ...provide,
      },
    });
  };

  const setupDashboard = (dashboardResponse, slug = '', provide = {}) => {
    mockDashboardResponse(dashboardResponse);
    mockAvailableVisualizationsResponse(TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE);
    createWrapper({
      routeSlug: slug,
      provide,
    });

    return waitForPromises();
  };

  describe('when mounted', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
    });

    it('should render with mock dashboard', async () => {
      createWrapper();

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: '',
        isGroup: false,
        isProject: true,
      });

      expect(findDashboard().props()).toMatchObject({
        initialDashboard: getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
        changesSaved: false,
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');
    });

    it('should render the loading icon while fetching data', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      expect(findLoader().exists()).toBe(true);

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
    });

    it('should render dashboard by slug', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: 'audience',
        isGroup: false,
        isProject: true,
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');

      expect(findDashboard().exists()).toBe(true);
    });

    it('should not render invalid dashboard alert', async () => {
      createWrapper();

      await waitForPromises();

      expect(findInvalidDashboardAlert().exists()).toBe(false);
    });

    it('should not render the usage overview aggregation warning', async () => {
      createWrapper();

      await waitForPromises();

      expect(findUsageOverviewAggregationWarning().exists()).toBe(false);
    });

    it('should add unique panel ids to each panel', async () => {
      createWrapper();

      await waitForPromises();

      expect(findDashboard().props().initialDashboard.panels).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: expect.stringContaining('panel-'),
          }),
        ]),
      );
    });

    it('renders an analytics dashboard panel component for each panel', async () => {
      createWrapper();

      await waitForPromises();

      const { panels } = getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(findAllPanels()).toHaveLength(panels.length);

      panels.forEach((panel) => {
        expect(findPanelByTitle(panel.title).props()).toMatchObject({
          title: panel.title,
          visualization: panel.visualization,
          queryOverrides: panel.queryOverrides || undefined,
          filters: buildDefaultDashboardFilters(''),
          editing: false,
        });
      });
    });

    it('should not add the after-description link to the dashboard by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findAfterDescriptionLink().exists()).toBe(false);
    });

    describe('and a panel emits a "delete" event', () => {
      beforeEach(async () => {
        createWrapper();

        await waitForPromises();

        findAllPanels().at(0).vm.$emit('delete');
      });

      it('calls the delete method on CustomizableDashboard', () => {
        expect(mockCustomizableDashboardDeletePanel).toHaveBeenCalled();
      });
    });

    it('should not render filters by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findUrlSync().exists()).toBe(false);
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
    });
  });

  describe('when dashboard fails to load', () => {
    let error = new Error();

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

      createWrapper();
      return waitForPromises();
    });

    it('does not render the dashboard, loader or feedback banners', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
      expect(findValueStreamFeedbackBanner().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('creates an alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining(
          'ruh roh some error. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}',
        ),
        messageLinks: {
          link: '/help/user/analytics/analytics_dashboards#troubleshooting',
        },
        captureError: true,
        error,
        title: 'Failed to load dashboard',
      });
    });

    describe('with a specified error message', () => {
      error = new Error('ruh roh some error');

      beforeEach(() => {
        mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

        createWrapper();
        return waitForPromises();
      });

      it('creates an alert with the error message and a troubleshooting link', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringContaining(
            'ruh roh some error. Refresh the page to try again or see %{linkStart}troubleshooting documentation%{linkEnd}',
          ),
          messageLinks: {
            link: '/help/user/analytics/analytics_dashboards#troubleshooting',
          },
          captureError: true,
          error,
          title: 'Failed to load dashboard',
        });
      });
    });
  });

  describe('when a custom dashboard cannot be found', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_404_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the dashboard or loader', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('renders the empty state', () => {
      expect(findEmptyState().props()).toMatchObject({
        svgPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        title: 'Dashboard not found',
        description: 'No dashboard matches the specified URL path.',
        primaryButtonText: 'View available dashboards',
        primaryButtonLink: TEST_ROUTER_BACK_HREF,
      });
    });
  });

  describe("when the dashboard's configuration is invalid", () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('renders the dashboard', () => {
      expect(findDashboard().exists()).toBe(true);
    });

    it('renders an alert with error messages', () => {
      expect(findInvalidDashboardAlert().props()).toMatchObject({
        title: 'Invalid dashboard configuration',
        primaryButtonText: 'Learn more',
        primaryButtonLink: '/help/user/analytics/analytics_dashboards#troubleshooting',
        dismissible: false,
      });

      mockInvalidDashboardErrors.forEach((error) =>
        expect(findInvalidDashboardAlert().text()).toContain(error),
      );
    });
  });

  describe('available visualizations', () => {
    it('fetches the available visualizations when a custom dashboard is loaded', async () => {
      await setupDashboard(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(mockAvailableVisualizationsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        isGroup: false,
        isProject: true,
      });

      const visualizations =
        TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE.data.project
          .customizableDashboardVisualizations.nodes;

      expect(findDashboard().props().availableVisualizations).toMatchObject({
        loading: false,
        visualizations,
      });
    });

    it('fetches the available visualizations from the backend when a dashboard is new', async () => {
      await setupDashboard(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE, NEW_DASHBOARD);

      expect(mockAvailableVisualizationsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        isGroup: false,
        isProject: true,
      });
    });

    it('does not fetch the available visualizations when a builtin dashboard is loaded it', async () => {
      await setupDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(mockAvailableVisualizationsHandler).not.toHaveBeenCalled();
      expect(findDashboard().props().availableVisualizations).toMatchObject({});
    });

    it('does not fetch the available visualizations when a dashboard was not loaded', async () => {
      await setupDashboard(TEST_DASHBOARD_GRAPHQL_404_RESPONSE);

      expect(mockAvailableVisualizationsHandler).not.toHaveBeenCalled();
      expect(findDashboard().exists()).toBe(false);
    });

    describe('when available visualizations fail to load', () => {
      const error = new Error('ruh roh some error');

      beforeEach(() => {
        mockDashboardResponse(TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
        mockAvailableVisualizationsHandler = jest.fn().mockRejectedValue(error);

        createWrapper({
          routeSlug:
            TEST_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards
              .nodes[0]?.slug,
        });
        return waitForPromises();
      });

      it('renders the dashboard', () => {
        expect(findDashboard().exists()).toBe(true);
      });

      it('sets error state on the visualizations drawer', () => {
        expect(findDashboard().props().availableVisualizations).toMatchObject({
          loading: false,
          hasError: true,
          visualizations: [],
        });
      });

      it(`should capture the exception in Sentry`, () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });
  });

  describe('editingEnabled', () => {
    describe.each`
      userDefined | slug                             | customizableDashboardsAvailable | editingEnabled
      ${true}     | ${'some_dashboard'}              | ${true}                         | ${true}
      ${false}    | ${'some_dashboard'}              | ${true}                         | ${false}
      ${true}     | ${CUSTOM_VALUE_STREAM_DASHBOARD} | ${true}                         | ${false}
      ${false}    | ${CUSTOM_VALUE_STREAM_DASHBOARD} | ${true}                         | ${false}
      ${true}     | ${'some_dashboard'}              | ${false}                        | ${false}
      ${false}    | ${'some_dashboard'}              | ${false}                        | ${false}
      ${true}     | ${CUSTOM_VALUE_STREAM_DASHBOARD} | ${false}                        | ${false}
      ${false}    | ${CUSTOM_VALUE_STREAM_DASHBOARD} | ${false}                        | ${false}
    `(
      'when userDefined is $userDefined, customizableDashboardsAvailable is $customizableDashboardsAvailable, slug is $slug',
      ({ userDefined, slug, customizableDashboardsAvailable, editingEnabled }) => {
        beforeEach(async () => {
          setupDashboard(
            createDashboardGraphqlSuccessResponse(
              getGraphQLDashboardWithPanels({ userDefined, slug }),
            ),
            slug,
            { customizableDashboardsAvailable },
          );

          await waitForPromises();
        });
        it(`should set editingEnabled to ${editingEnabled}`, () => {
          expect(findDashboard().props('editingEnabled')).toBe(editingEnabled);
        });
      },
    );
  });

  describe('dashboard editor', () => {
    beforeEach(() =>
      mockAvailableVisualizationsResponse(TEST_VISUALIZATIONS_GRAPHQL_SUCCESS_RESPONSE),
    );

    describe('when saving', () => {
      beforeEach(() => {
        mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

        createWrapper({
          routeSlug: 'custom_dashboard',
        });
      });

      describe('with a valid dashboard', () => {
        let originalPanels;

        beforeEach(async () => {
          await waitForPromises();

          originalPanels = findDashboard().props().initialDashboard.panels;

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        });

        it('saves the dashboard and shows a success toast', () => {
          expect(saveCustomDashboard).toHaveBeenCalledWith({
            dashboardSlug: 'analytics_overview',
            dashboardConfig: expect.objectContaining({
              title: 'Analytics Overview',
              panels: expect.any(Array),
            }),
            projectInfo: TEST_CUSTOM_DASHBOARDS_PROJECT,
            isNewFile: false,
          });

          expect(showToast).toHaveBeenCalledWith('Dashboard was saved successfully');
        });

        it('sets changesSaved to true on the dashboard component', () => {
          expect(findDashboard().props('changesSaved')).toBe(true);
        });

        it(`tracks the "${EVENT_LABEL_EDITED_DASHBOARD}" event`, () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_EDITED_DASHBOARD,
            {
              label: 'Analytics Overview',
            },
            undefined,
          );
        });

        it('persists the original panels array after saving', () => {
          expect(findDashboard().props().initialDashboard.panels).toStrictEqual(originalPanels);
        });
      });

      describe('with an invalid dashboard', () => {
        it('does not save when dashboard has no title', async () => {
          const { title, ...dashboardWithNoTitle } = dashboard;
          await mockSaveDashboardImplementation(
            () => ({ status: HTTP_STATUS_CREATED }),
            dashboardWithNoTitle,
          );

          expect(saveCustomDashboard).not.toHaveBeenCalled();
        });
      });

      describe('dashboard errors', () => {
        it('creates an alert when the response status is HTTP_STATUS_FORBIDDEN', async () => {
          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_FORBIDDEN }));

          expect(createAlert).toHaveBeenCalledWith({
            message: 'Error while saving dashboard',
            captureError: true,
            error: new Error(`Bad save dashboard response. Status:${HTTP_STATUS_FORBIDDEN}`),
            title: '',
          });
        });

        it('creates an alert when the fetch request throws an error', async () => {
          const newError = new Error();
          await mockSaveDashboardImplementation(() => {
            throw newError;
          });

          expect(createAlert).toHaveBeenCalledWith({
            error: newError,
            message: 'Error while saving dashboard',
            captureError: true,
            title: '',
          });
        });

        it('clears the alert when the component is destroyed', async () => {
          await mockSaveDashboardImplementation(() => {
            throw new Error();
          });

          wrapper.destroy();

          await nextTick();

          expect(mockAlertDismiss).toHaveBeenCalled();
        });

        it('clears the alert when the dashboard saved successfully', async () => {
          await mockSaveDashboardImplementation(() => {
            throw new Error();
          });

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));

          expect(mockAlertDismiss).toHaveBeenCalled();
        });
      });

      it('renders an alert with the server message when a bad request was made', async () => {
        createWrapper({
          routeSlug: 'custom_dashboard',
        });

        const message = 'File already exists';
        const badRequestError = new Error();

        badRequestError.response = {
          status: HTTP_STATUS_BAD_REQUEST,
          data: { message },
        };

        await mockSaveDashboardImplementation(() => {
          throw badRequestError;
        });

        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          message,
          error: badRequestError,
          captureError: false,
          title: '',
        });
      });

      it('updates the apollo cache', async () => {
        createWrapper({
          routeSlug: dashboard.slug,
        });

        await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        await waitForPromises();

        expect(updateApolloCache).toHaveBeenCalledWith({
          apolloClient: expect.any(Object),
          slug: dashboard.slug,
          dashboard: expect.objectContaining({
            slug: 'analytics_overview',
            title: 'Analytics Overview',
            userDefined: true,
          }),
          fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
          isGroup: false,
          isProject: true,
        });
      });
    });

    describe('when a dashboard is new', () => {
      beforeEach(() => {
        createWrapper({
          props: { isNewDashboard: true },
        });

        return waitForPromises();
      });

      it('creates a new dashboard', () => {
        expect(findDashboard().props()).toMatchObject({
          initialDashboard: {
            ...NEW_DASHBOARD,
          },
        });
      });

      it(`tracks the "${EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD}" event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(
          EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
          {},
          undefined,
        );
      });

      it(`tracks the "${EVENT_LABEL_VIEWED_DASHBOARD}" event`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledWith(EVENT_LABEL_VIEWED_DASHBOARD, {}, undefined);
      });

      describe('when saving', () => {
        let originalPanels;

        beforeEach(async () => {
          await waitForPromises();

          originalPanels = findDashboard().props().initialDashboard.panels;

          await mockSaveDashboardImplementation(() => ({ status: HTTP_STATUS_CREATED }));
        });

        it('saves the dashboard as a new file', () => {
          expect(saveCustomDashboard).toHaveBeenCalledWith({
            dashboardSlug: 'analytics_overview',
            dashboardConfig: expect.objectContaining({
              title: 'Analytics Overview',
              panels: expect.any(Array),
            }),
            projectInfo: TEST_CUSTOM_DASHBOARDS_PROJECT,
            isNewFile: true,
          });
        });

        it(`tracks the "${EVENT_LABEL_CREATED_DASHBOARD}" event`, () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_CREATED_DASHBOARD,
            {
              label: 'Analytics Overview',
            },
            undefined,
          );
        });

        it('persists the original panels array after saving', () => {
          expect(findDashboard().props().initialDashboard.panels).toStrictEqual(originalPanels);
        });
      });
    });
  });

  describe.each`
    userDefined | event                                   | title
    ${false}    | ${EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD} | ${'Audience'}
    ${true}     | ${EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD}  | ${'My custom dashboard'}
  `('when a dashboard is userDefined=$userDefined is viewed', ({ userDefined, event, title }) => {
    beforeEach(() => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(
          getGraphQLDashboardWithPanels({ userDefined, title }),
        ),
      );

      return waitForPromises();
    });

    it(`tracks the "${event}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(event, { label: title }, undefined);
    });

    it(`tracks the "${EVENT_LABEL_VIEWED_DASHBOARD}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_LABEL_VIEWED_DASHBOARD,
        { label: title },
        undefined,
      );
    });

    it('tracks exactly two events', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('with a built-in product analytics dashboards dashboard', () => {
    it.each`
      slug          | userDefined | showsBanner
      ${'audience'} | ${false}    | ${true}
      ${'behavior'} | ${false}    | ${true}
      ${'vsd'}      | ${false}    | ${false}
      ${'audience'} | ${true}     | ${false}
    `(
      'when the dashboard slug is "$slug" and userDefined is $userDefined then the banner is $showsBanner',
      async ({ slug, userDefined, showsBanner }) => {
        setupDashboard(
          createDashboardGraphqlSuccessResponse(
            getGraphQLDashboardWithPanels({ slug, userDefined }),
          ),
        );

        await waitForPromises();

        expect(findProductAnalyticsFeedbackBanner().exists()).toBe(showsBanner);
      },
    );
  });

  describe('filters', () => {
    const defaultFilters = buildDefaultDashboardFilters('');
    let trackEventSpy;

    const setupGroupDashboardWithFilters = (filters) => {
      setupDashboard(
        createGroupDashboardGraphqlSuccessResponse(getGraphQLDashboardWithPanels({ filters })),
        'test-dashboard-with-filters',
      );

      createWrapper({
        provide: {
          namespaceId: TEST_CUSTOM_DASHBOARDS_GROUP.id,
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });
      return waitForPromises();
    };

    const setupDashboardWithFilters = (filters) => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(getGraphQLDashboardWithPanels({ filters })),
        'test-dashboard-with-filters',
      );
      createWrapper({});
      return waitForPromises();
    };

    describe('anonymous user filter', () => {
      beforeEach(async () => {
        await setupDashboardWithFilters({ excludeAnonymousUsers: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultFilters),
        });
      });

      it('sets the default filter on the anon users filter component', () => {
        expect(findAnonUsersFilter().props('value')).toBe(defaultFilters.filterAnonUsers);
      });

      it('sets the panel filter', () => {
        expect(findAllPanels().at(0).props('filters')).toMatchObject({
          filterAnonUsers: defaultFilters.filterAnonUsers,
        });
      });

      describe('when filter changes', () => {
        beforeEach(() => {
          trackEventSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
        });

        beforeEach(async () => {
          findAnonUsersFilter().vm.$emit('change', true);
          await waitForPromises();
        });

        it('updates the filter on the anon users filter component', () => {
          expect(findAnonUsersFilter().props('value')).toBe(true);
        });

        it('updates the panel filter', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            filterAnonUsers: true,
          });
        });
        it(`tracks the "${EVENT_LABEL_EXCLUDE_ANONYMISED_USERS}" event when excluding anon users`, () => {
          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
            {},
            undefined,
          );
        });

        it(`does not track "${EVENT_LABEL_EXCLUDE_ANONYMISED_USERS}" event including anon users`, async () => {
          trackEventSpy.mockClear();

          await findAnonUsersFilter().vm.$emit('change', false);

          expect(trackEventSpy).not.toHaveBeenCalled();
        });
      });
    });

    describe('projects  filter', () => {
      const findDropdownGroupNamespace = () => findProjectsFilter().props('groupNamespace');

      describe('when dashboard is group-level', () => {
        beforeEach(async () => {
          await setupGroupDashboardWithFilters({ projects: { enabled: true } });
        });

        it('renders the filter', () => {
          expect(findProjectsFilter().exists()).toBe(true);
          expect(findDropdownGroupNamespace()).toBe(TEST_CUSTOM_DASHBOARDS_GROUP.fullPath);
        });

        it('synchronizes the filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams(defaultFilters),
          });
        });

        describe('on project selection', () => {
          const selectedProject = {
            id: 'gid://test-project',
            name: 'test-project',
            fullPath: 'test/project',
          };

          beforeEach(async () => {
            await findProjectsFilter().vm.$emit('projectSelected', selectedProject);
          });

          it('synchronizes the filters with the URL', () => {
            expect(findUrlSync().props()).toMatchObject({
              historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
              urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
              query: filtersToQueryParams({ projectFullPath: selectedProject.fullPath }),
            });
          });

          it('updates the slot filters', () => {
            expect(findAllPanels().at(0).props('filters')).toMatchObject({
              projectFullPath: selectedProject.fullPath,
            });
          });
        });
      });

      describe('when dashboard is project-level', () => {
        beforeEach(async () => {
          await setupDashboardWithFilters({ projectSelector: { enabled: true } }, false);
        });
        it('does not render the filter', () => {
          expect(findProjectsFilter().exists()).toBe(false);
        });
      });
    });

    describe('date range filter', () => {
      const defaultDateRangeFilters = buildDefaultDashboardFilters('', {
        dateRange: { enabled: true },
      });

      beforeEach(async () => {
        await setupDashboardWithFilters({ dateRange: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultDateRangeFilters),
        });
      });

      it('shows the date range filter and passes the default options and filters', () => {
        expect(findDateRangeFilter().props()).toMatchObject({
          startDate: defaultDateRangeFilters.startDate,
          endDate: defaultDateRangeFilters.endDate,
          defaultOption: defaultDateRangeFilters.dateRangeOption,
          dateRangeLimit: 0,
        });
      });

      it('sets the date range limit based on config if it exists', async () => {
        await setupDashboardWithFilters({ dateRange: { enabled: true, numberOfDaysLimit: 99 } });
        expect(findDateRangeFilter().props('dateRangeLimit')).toBe(99);
      });

      it('sets the date range options based on config if it exists', async () => {
        await setupDashboardWithFilters({
          dateRange: {
            enabled: true,
            options: [DATE_RANGE_OPTION_TODAY, DATE_RANGE_OPTION_CUSTOM],
          },
        });

        expect(findDateRangeFilter().props('options')).toEqual([
          DATE_RANGE_OPTION_TODAY,
          DATE_RANGE_OPTION_CUSTOM,
        ]);
      });

      it('displays a warning when the defaultOption is not in the list of options', async () => {
        await setupDashboardWithFilters({
          dateRange: {
            enabled: true,
            defaultOption: DATE_RANGE_OPTION_LAST_7_DAYS,
            options: [DATE_RANGE_OPTION_TODAY, DATE_RANGE_OPTION_CUSTOM],
          },
        });

        expect(createAlert).toHaveBeenCalledWith({
          title: 'Date range filter validation',
          message: "Default date range '7d' is not included in the list of dateRange options",
        });
      });

      it('sets the panel filters', () => {
        expect(findAllPanels().at(0).props('filters')).toMatchObject({
          dateRangeOption: defaultDateRangeFilters.dateRangeOption,
          startDate: defaultDateRangeFilters.startDate,
          endDate: defaultDateRangeFilters.endDate,
        });
      });

      describe('when filters change', () => {
        beforeEach(async () => {
          await findDateRangeFilter().vm.$emit('change', mockDateRangeFilterChangePayload);
        });
        it('updates the slot filters', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            dateRangeOption: mockDateRangeFilterChangePayload.dateRangeOption,
            startDate: mockDateRangeFilterChangePayload.startDate,
            endDate: mockDateRangeFilterChangePayload.endDate,
          });
        });

        it('synchronizes the updated filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams(mockDateRangeFilterChangePayload),
          });
        });
      });
    });

    describe('filtered search filter', () => {
      beforeEach(async () => {
        await setupDashboardWithFilters({ filteredSearch: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultFilters),
        });
      });

      it('shows the filtered search filter', () => {
        expect(findFilteredSearchFilter().props()).toMatchObject({
          initialFilterValue: defaultFilters.searchFilters,
        });
      });

      it('sets the filtered search options when they are present', async () => {
        const mockFilteredSearchOptions = [{ token: 'assignee', unique: true }];

        await setupDashboardWithFilters({
          filteredSearch: {
            enabled: true,
            options: mockFilteredSearchOptions,
          },
        });

        expect(findFilteredSearchFilter().props('options')).toEqual(mockFilteredSearchOptions);
      });

      describe('when filters change', () => {
        beforeEach(async () => {
          await findFilteredSearchFilter().vm.$emit('change', mockFilteredSearchChangePayload);
        });

        it('updates the slot filters', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            searchFilters: mockFilteredSearchChangePayload,
          });
        });

        it('synchronizes the updated filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams({ searchFilters: mockFilteredSearchChangePayload }),
          });
        });

        it(`updates the search filter's initial value with the updated filters`, () => {
          expect(findFilteredSearchFilter().props('initialFilterValue')).toEqual(
            mockFilteredSearchChangePayload,
          );
        });
      });
    });
  });

  describe('with an AI impact dashboard', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      return waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'AI impact analytics',
          slug: 'ai_impact',
        },
      });
    });

    it('does not render the value stream feedback banner', () => {
      expect(findValueStreamFeedbackBanner().exists()).toBe(false);
    });

    it('does not render the product analytics feedback banner', () => {
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
    });

    it('adds the after-description link to the dashboard', () => {
      const linkWrapper = findAfterDescriptionLink();
      const links = linkWrapper.findAllComponents(GlLink);

      expect(linkWrapper.text()).toBe('Learn more about AI impact analytics and GitLab Duo seats.');

      const expectedLinks = [
        {
          text: 'AI impact analytics',
          href: '/help/user/analytics/ai_impact_analytics',
        },
        {
          text: 'GitLab Duo seats',
          href: '/help/subscriptions/subscription-add-ons',
        },
      ];

      expectedLinks.forEach((expected, index) => {
        const link = links.at(index);
        expect(link.text()).toBe(expected.text);
        expect(link.attributes('href')).toBe(expected.href);
      });
    });

    it('does not render filters', () => {
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findProjectsFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
      expect(findUrlSync().exists()).toBe(false);
    });
  });

  describe('with a value stream dashboard', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      await waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
        },
      });
    });

    it('renders the value stream feedback banner', () => {
      expect(findValueStreamFeedbackBanner().exists()).toBe(true);
    });

    it('does not render the product analytics feedback banner', () => {
      expect(findProductAnalyticsFeedbackBanner().exists()).toBe(false);
    });

    it('adds the after-description link to the dashboard', () => {
      const linkWrapper = findAfterDescriptionLink();

      expect(linkWrapper.text()).toBe('Learn more.');
      expect(linkWrapper.findComponent(GlLink).attributes('href')).toBe(
        '/help/user/analytics/value_streams_dashboard',
      );
    });

    it('does not render filters', () => {
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
      expect(findUrlSync().exists()).toBe(false);
    });
  });

  describe('with a group namespace', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceId: TEST_CUSTOM_DASHBOARDS_GROUP.id,
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });
      await waitForPromises();
    });

    it('will fetch the group data', () => {
      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
        slug: 'value_streams_dashboard',
        isGroup: true,
        isProject: false,
      });
    });

    it('will set the initialDashboard data', async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceId: TEST_CUSTOM_DASHBOARDS_GROUP.id,
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });

      await waitForPromises();

      expect(findDashboard().props()).toMatchObject({
        initialDashboard: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
          panels: [],
        },
      });
    });
  });

  describe('when the route changes', () => {
    const nextMock = jest.fn();

    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
    });

    const setupWithConfirmation = async (confirmMock, provide = {}) => {
      createWrapper({ stubMockMethods: { confirmDiscardIfChanged: confirmMock }, provide });

      await waitForPromises();

      wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

      await waitForPromises();
    };

    it('routes to the next route when a user confirmed to discard changes', async () => {
      const confirmMock = jest.fn().mockResolvedValue(true);

      await setupWithConfirmation(confirmMock);

      expect(confirmMock).toHaveBeenCalledTimes(1);
      expect(nextMock).toHaveBeenCalled();
    });

    it('does not route to the next route when a user does not confirm to discard changes', async () => {
      const confirmMock = jest.fn().mockResolvedValue(false);

      await setupWithConfirmation(confirmMock);

      expect(confirmMock).toHaveBeenCalledTimes(1);
      expect(nextMock).not.toHaveBeenCalled();
    });

    describe('when customizableDashboardsAvailable is false', () => {
      it.each([true, false])(
        'routes to the next page when confirmed changes is %s',
        async (confirmed) => {
          const confirmMock = jest.fn().mockResolvedValue(confirmed);

          await setupWithConfirmation(confirmMock, { customizableDashboardsAvailable: false });

          expect(nextMock).toHaveBeenCalled();
        },
      );
    });
  });

  describe('when usage overview aggregation is not enabled', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        provide: {
          overviewCountsAggregationEnabled: false,
        },
      });

      await waitForPromises();
    });

    it('renders the usage overview aggregation warning', () => {
      expect(findUsageOverviewAggregationWarning().exists()).toBe(true);
    });
  });
});
