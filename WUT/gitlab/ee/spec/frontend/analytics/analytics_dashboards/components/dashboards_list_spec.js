import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { mockTracking } from 'helpers/tracking_helper';
import ProductAnalyticsOnboarding from 'ee/product_analytics/onboarding/components/onboarding_list_item.vue';
import DashboardsList from 'ee/analytics/analytics_dashboards/components/dashboards_list.vue';
import DashboardListItem from 'ee/analytics/analytics_dashboards/components/list/dashboard_list_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { InternalEvents } from '~/tracking';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import getAllCustomizableDashboardsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_dashboards.query.graphql';
import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { saveCustomDashboard } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { getDashboardConfig } from '~/vue_shared/components/customizable_dashboard/utils';
import { updateApolloCache } from 'ee/analytics/analytics_dashboards/utils';
import {
  TEST_COLLECTOR_HOST,
  TEST_TRACKING_KEY,
  TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE,
  TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_AUDIENCE_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
} from '../mock_data';

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

Vue.use(VueApollo);

describe('DashboardsList', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;

  const findListItems = () => wrapper.findAllComponents(DashboardListItem);
  const findListLoadingSkeletons = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findProductAnalyticsOnboarding = () => wrapper.findComponent(ProductAnalyticsOnboarding);
  const findPageTitle = () => wrapper.findByTestId('page-heading');
  const findPageDescription = () => wrapper.findByTestId('page-heading-description');
  const findHelpLink = () => wrapper.findByTestId('help-link');
  const findNewDashboardButton = () => wrapper.findByTestId('new-dashboard-button');
  const findDataExplorerButton = () => wrapper.findByTestId('data-explorer-button');
  const findConfigureAlert = () => wrapper.findComponent(GlAlert);

  const $router = {
    push: jest.fn(),
  };
  const showToastMock = jest.fn();
  const $toast = {
    show: showToastMock,
  };

  let mockAnalyticsDashboardsHandler = jest.fn();
  let mockAnalyticsDashboardDetailsHandler = jest.fn();

  const createWrapper = (provided = {}) => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);

    const mockApollo = createMockApollo([
      [getAllCustomizableDashboardsQuery, mockAnalyticsDashboardsHandler],
      [getCustomizableDashboardQuery, mockAnalyticsDashboardDetailsHandler],
    ]);

    wrapper = shallowMountExtended(DashboardsList, {
      apolloProvider: mockApollo,
      stubs: {
        RouterLink: true,
        PageHeading,
        GlSprintf,
      },
      mocks: {
        $router,
        $toast,
      },
      provide: {
        isProject: true,
        isGroup: false,
        collectorHost: TEST_COLLECTOR_HOST,
        trackingKey: TEST_TRACKING_KEY,
        canConfigureProjectSettings: true,
        namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        analyticsSettingsPath: '/test/-/settings#foo',
        canCreateNewDashboard: false,
        customizableDashboardsAvailable: false,
        ...provided,
      },
    });
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler.mockReset();
    mockAnalyticsDashboardDetailsHandler.mockReset();
  });

  describe('by default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render the page title', () => {
      expect(findPageTitle().text()).toBe('Analytics dashboards');
    });

    it('should render the default description with link', () => {
      expect(findPageDescription().text()).toBe(
        'Learn more about managing and interacting with analytics dashboards.',
      );
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('does not render any custom dashboards', () => {
      expect(findListItems()).toHaveLength(0);
    });

    it('should track the dashboard list has been viewed', () => {
      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'user_viewed_dashboard_list',
        expect.any(Object),
      );
    });

    it('fetches the list of dashboards', () => {
      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        isGroup: false,
        isProject: true,
      });
    });

    it('renders a loading state', () => {
      expect(findListLoadingSkeletons()).toHaveLength(2);
    });
  });

  describe('with successful dashboards query', () => {
    const setupDashboardQuery = (options) => {
      mockAnalyticsDashboardsHandler = jest
        .fn()
        .mockResolvedValue(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper(options);

      return waitForPromises();
    };

    describe('dashboard actions dropdown visibility', () => {
      it.each`
        canCreateNewDashboard | expectedVisibility
        ${false}              | ${false}
        ${true}               | ${true}
      `(
        'shows user actions=$expectedVisibility when canCreateNewDashboard=$canCreateNewDashboard',
        async ({ canCreateNewDashboard, expectedVisibility }) => {
          await setupDashboardQuery({ canCreateNewDashboard });

          expect(findListItems().at(0).props('showUserActions')).toBe(expectedVisibility);
        },
      );
    });
  });

  describe('new dashboard button visibility', () => {
    it.each`
      canCreateNewDashboard | expectedVisibility
      ${false}              | ${false}
      ${true}               | ${true}
    `(
      'shows user actions=$expectedVisibility when canCreateNewDashboard=$canCreateNewDashboard',
      ({ canCreateNewDashboard, expectedVisibility }) => {
        createWrapper({ canCreateNewDashboard });

        expect(findNewDashboardButton().exists()).toBe(expectedVisibility);
      },
    );
  });

  describe('for projects', () => {
    it('does not render the data explorer button', () => {
      createWrapper();

      expect(findDataExplorerButton().exists()).toBe(false);
    });

    describe('when customizableDashboardsAvailable = true', () => {
      beforeEach(() => {
        createWrapper({ customizableDashboardsAvailable: true });
      });
      it('should render the page description', () => {
        expect(findPageDescription().text()).toContain(
          'Dashboards are created by editing the projects dashboard files.',
        );
      });
      it('should render the help link', () => {
        expect(findHelpLink().text()).toBe('Learn more.');
        expect(findHelpLink().attributes('href')).toBe(
          helpPagePath('user/analytics/analytics_dashboards'),
        );
      });
    });

    describe('when custom dashboards project is configured', () => {
      it('does not render the data explorer button', () => {
        createWrapper();

        expect(findDataExplorerButton().exists()).toBe(false);
      });

      describe('when product analytics is onboarded', () => {
        beforeEach(async () => {
          mockAnalyticsDashboardsHandler = jest
            .fn()
            .mockResolvedValue(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);

          createWrapper({
            features: ['productAnalytics'],
            customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
          });

          await waitForPromises();

          findProductAnalyticsOnboarding().vm.$emit('complete');
        });

        it('should show the data explorer button', () => {
          expect(findDataExplorerButton().exists()).toBe(true);
        });
      });
    });
  });

  describe('for groups', () => {
    it('does not render the data explorer button', () => {
      createWrapper({ isProject: false, isGroup: true });

      expect(findDataExplorerButton().exists()).toBe(false);
    });

    describe('when customizableDashboardsAvailable = true', () => {
      beforeEach(() => {
        createWrapper({ customizableDashboardsAvailable: true, isProject: false, isGroup: true });
      });
      it('should render the page description', () => {
        expect(findPageDescription().text()).toContain(
          'Dashboards are created by editing the groups dashboard files.',
        );
      });
      it('should render the help link', () => {
        expect(findHelpLink().text()).toBe('Learn more.');
        expect(findHelpLink().attributes('href')).toBe(
          helpPagePath('user/analytics/analytics_dashboards'),
        );
      });
    });

    describe('with successful dashboards query', () => {
      beforeEach(() => {
        mockAnalyticsDashboardsHandler = jest
          .fn()
          .mockResolvedValue(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

        createWrapper({ isProject: false, isGroup: true });

        return waitForPromises();
      });

      it('should render the Value streams dashboards link', () => {
        expect(findListItems()).toHaveLength(1);

        const dashboardAttributes = findListItems().at(0).props('dashboard');

        expect(dashboardAttributes).toMatchObject({
          slug: 'value_streams_dashboard',
          title: 'Value Streams Dashboard',
        });
      });
    });
  });

  describe('configure custom dashboards project', () => {
    describe.each`
      customizableDashboardsAvailable | canConfigureProjectSettings | showBanner
      ${true}                         | ${true}                     | ${true}
      ${true}                         | ${false}                    | ${false}
      ${false}                        | ${true}                     | ${false}
      ${false}                        | ${false}                    | ${false}
    `(
      'with customizableDashboardsAvailable=$customizableDashboardsAvailable, canConfigureProjectSettings=$canConfigureProjectSettings',
      ({ canConfigureProjectSettings, customizableDashboardsAvailable, showBanner }) => {
        beforeEach(() => {
          createWrapper({
            customDashboardsProject: null,
            customizableDashboardsAvailable,
            canConfigureProjectSettings,
          });
        });

        it(`does ${showBanner ? '' : 'not '}show the custom dashboard setup alert`, () => {
          expect(findConfigureAlert().exists()).toBe(showBanner);
        });
      },
    );
  });

  describe('when the product analytics feature is enabled', () => {
    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest
        .fn()
        .mockResolvedValue(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({ features: ['productAnalytics'] });
    });

    it('renders the onboarding component', () => {
      expect(findProductAnalyticsOnboarding().exists()).toBe(true);
    });

    describe('when the onboarding component emits "complete"', () => {
      beforeEach(async () => {
        await waitForPromises();

        findProductAnalyticsOnboarding().vm.$emit('complete');
      });

      it('removes the onboarding component from the DOM', () => {
        expect(findProductAnalyticsOnboarding().exists()).toBe(false);
      });

      it('refetches the list of dashboards', () => {
        expect(findListLoadingSkeletons()).toHaveLength(2);
        expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledTimes(2);
      });
    });

    describe('when the onboarding component emits "error"', () => {
      const message = 'some error';
      const error = new Error(message);

      beforeEach(async () => {
        await waitForPromises();

        findProductAnalyticsOnboarding().vm.$emit('error', error, true, message);
      });

      it('creates an alert for the error', () => {
        expect(createAlert).toHaveBeenCalledWith({
          captureError: true,
          message,
          error,
        });
      });

      it('dismisses the alert when the component is destroyed', async () => {
        wrapper.destroy();

        await nextTick();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });
    });
  });

  describe('when the list of dashboards have been fetched', () => {
    const setupWithResponse = (mockResponseVal) => {
      mockAnalyticsDashboardsHandler = jest.fn().mockResolvedValue(mockResponseVal);

      createWrapper();

      return waitForPromises();
    };

    describe('and there are dashboards', () => {
      beforeEach(() => {
        return setupWithResponse(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);
      });

      it('does not render a loading state', () => {
        expect(findListLoadingSkeletons()).toHaveLength(0);
      });

      it('renders a list item for each custom dashboard', () => {
        const expectedDashboards =
          TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data?.project?.customizableDashboards?.nodes;

        expect(findListItems()).toHaveLength(expectedDashboards.length);

        expectedDashboards.forEach(async (dashboard, idx) => {
          const dashboardItem = findListItems().at(idx);
          expect(dashboardItem.props('dashboard')).toEqual(dashboard);
          expect(dashboardItem.attributes()['data-event-tracking']).toBe('user_visited_dashboard');

          InternalEvents.bindInternalEventDocument(dashboardItem.element);
          await dashboardItem.trigger('click');
          await nextTick();

          expect(trackingSpy).toHaveBeenCalledWith(
            undefined,
            'user_visited_dashboard',
            expect.any(Object),
          );
        });
      });
    });

    describe('and the response is empty', () => {
      beforeEach(() => {
        return setupWithResponse(TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE);
      });

      it('does not render a loading state', () => {
        expect(findListLoadingSkeletons()).toHaveLength(0);
      });

      it('does not render any list items', () => {
        expect(findListItems()).toHaveLength(0);
      });
    });
  });

  describe('when an error occurred while fetching the list of dashboards', () => {
    const message = 'failed';
    const error = new Error(message);

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

      createWrapper();

      return waitForPromises();
    });

    it('creates an alert for the error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        message,
        error,
      });
    });
  });

  describe('dashboard cloning', () => {
    const [dashboard, dashboard2] =
      TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards.nodes;
    const [referenceConfig] =
      TEST_AUDIENCE_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards.nodes;

    const setupCloningWithSaveStatus = async (status) => {
      mockAnalyticsDashboardsHandler = jest
        .fn()
        .mockResolvedValue(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);
      mockAnalyticsDashboardDetailsHandler = jest
        .fn()
        .mockResolvedValue(TEST_AUDIENCE_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
      saveCustomDashboard.mockResolvedValue({ status });

      createWrapper({
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
      });

      await waitForPromises();

      findListItems().at(0).vm.$emit('clone', dashboard.slug);
    };

    describe('when busy cloning', () => {
      beforeEach(() => {
        return setupCloningWithSaveStatus(HTTP_STATUS_CREATED);
      });

      it('shows the skeleton loader', () => {
        expect(findListLoadingSkeletons()).toHaveLength(1);
      });
    });

    describe('when cloning two dashboards at the same time', () => {
      beforeEach(async () => {
        await setupCloningWithSaveStatus(HTTP_STATUS_CREATED);

        findListItems().at(0).vm.$emit('clone', dashboard2.slug);
      });

      it('enqueues cloning of dashboards', async () => {
        expect(mockAnalyticsDashboardDetailsHandler).toHaveBeenCalledTimes(1);

        await waitForPromises();

        expect(mockAnalyticsDashboardDetailsHandler).toHaveBeenCalledTimes(2);
      });
    });

    describe('and the new dashboard is successfully created', () => {
      beforeEach(async () => {
        await setupCloningWithSaveStatus(HTTP_STATUS_CREATED);
        return waitForPromises();
      });

      it('fetches the full config of the reference dashboard', () => {
        expect(mockAnalyticsDashboardDetailsHandler).toHaveBeenCalledWith({
          fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
          isGroup: false,
          isProject: true,
          slug: dashboard.slug,
        });
      });

      it('saves a copy of the reference dashboard', () => {
        expect(saveCustomDashboard).toHaveBeenCalledWith({
          dashboardConfig: getDashboardConfig({
            ...referenceConfig,
            slug: 'audience_copy_copy',
            title: 'Audience (Copy) (Copy)',
            panels: referenceConfig.panels.nodes,
            userDefined: true,
          }),
          dashboardSlug: 'audience_copy_copy',
          isNewFile: true,
          projectInfo: TEST_CUSTOM_DASHBOARDS_PROJECT,
        });
      });

      it('creates a toast message', () => {
        expect(showToastMock).toHaveBeenCalledWith('Dashboard was cloned successfully');
      });

      it('updates the client apollo cache', () => {
        expect(updateApolloCache).toHaveBeenCalledWith({
          apolloClient: expect.any(Object),
          slug: 'audience_copy_copy',
          dashboard: expect.objectContaining({
            slug: 'audience_copy_copy',
            title: 'Audience (Copy) (Copy)',
            userDefined: true,
          }),
          fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
          isProject: true,
          isGroup: false,
        });
      });

      it('does not show the skeleton loader', () => {
        expect(findListLoadingSkeletons()).toHaveLength(0);
      });
    });

    describe('and an error occurs while cloning', () => {
      beforeEach(async () => {
        await setupCloningWithSaveStatus(null);
        return waitForPromises();
      });

      it('creates an alert for the error', () => {
        expect(createAlert).toHaveBeenCalledWith({
          captureError: true,
          message: 'Could not clone the dashboard. Refresh the page to try again.',
          error: expect.any(Error),
        });
      });

      it('does not show the skeleton loader', () => {
        expect(findListLoadingSkeletons()).toHaveLength(0);
      });

      describe('and a second attempt to clone the dashboard is successful', () => {
        beforeEach(() => {
          saveCustomDashboard.mockResolvedValue({ status: HTTP_STATUS_CREATED });
          findListItems().at(0).vm.$emit('clone', dashboard.slug);
          return waitForPromises();
        });

        it('clears the alert', () => {
          expect(mockAlertDismiss).toHaveBeenCalled();
        });
      });
    });
  });
});
