import createRouter from 'ee/analytics/analytics_dashboards/router';
import DashboardsList from 'ee/analytics/analytics_dashboards/components/dashboards_list.vue';
import AnalyticsDashboard from 'ee/analytics/analytics_dashboards/components/analytics_dashboard.vue';
import ProductAnalyticsOnboardingView from 'ee/product_analytics/onboarding/onboarding_view.vue';
import ProductAnalyticsOnboardingSetup from 'ee/product_analytics/onboarding/onboarding_setup.vue';
import AnalyticsDataExplorer from 'ee/analytics/analytics_dashboards/components/analytics_data_explorer.vue';

describe('Dashboards list router', () => {
  const base = '/dashboard';
  const breadcrumbState = {
    updateName: jest.fn(),
    name: '',
  };

  let router = null;
  afterEach(() => {
    router = null;
    breadcrumbState.name = '';
  });

  it('returns a router object', () => {
    router = createRouter(base, breadcrumbState, { canConfigureProjectSettings: true });

    // vue-router v3 and v4 store base at different locations
    expect(router.history?.base ?? router.options.history?.base).toBe(base);
  });

  describe('router', () => {
    beforeEach(() => {
      router = createRouter(base, breadcrumbState, { canConfigureProjectSettings: true });
    });

    it.each`
      path                               | component                          | name
      ${'/'}                             | ${DashboardsList}                  | ${'Analytics dashboards'}
      ${'/data-explorer'}                | ${AnalyticsDataExplorer}           | ${'Data explorer'}
      ${'/product-analytics-onboarding'} | ${ProductAnalyticsOnboardingView}  | ${'Product analytics onboarding'}
      ${'/product-analytics-setup'}      | ${ProductAnalyticsOnboardingSetup} | ${'Product analytics onboarding'}
      ${'/test-dashboard-1'}             | ${AnalyticsDashboard}              | ${'Test dashboard 1'}
      ${'/test-dashboard-2'}             | ${AnalyticsDashboard}              | ${'Test dashboard 2'}
    `('sets component as $component.name for path "$path"', async ({ path, component, name }) => {
      breadcrumbState.name = name;

      try {
        await router.push(path);
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      const [root] = router.currentRoute.matched;

      expect(router.currentRoute.meta.getName()).toBe(name);
      expect(root.components.default).toBe(component);
    });

    it('sets the root meta attribute to true for the root route', async () => {
      try {
        await router.push('/');
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(router.currentRoute.meta.root).toBe(true);
    });
  });

  describe('when user does not have permission to configure project settings', () => {
    beforeEach(() => {
      router = createRouter(base, breadcrumbState, { canConfigureProjectSettings: false });
    });

    it.each(['/product-analytics-onboarding', '/product-analytics-setup'])(
      'does not include the "%s" route',
      (onboardingRoute) => {
        const productAnalyticsOnboardingRoute = router.options.routes.find(
          (route) => route.path === onboardingRoute,
        );

        expect(productAnalyticsOnboardingRoute).toBeUndefined();
      },
    );
  });

  describe('/new route', () => {
    const getNewRoute = () => router.options.routes.find((route) => route.path === '/new');

    describe('when canCreateNewDashboard is true', () => {
      beforeEach(() => {
        router = createRouter(base, breadcrumbState, {
          canCreateNewDashboard: true,
        });
      });

      it('includes the /new route', () => {
        const newDashboardRoute = getNewRoute();

        expect(newDashboardRoute).toBeDefined();
        expect(newDashboardRoute.meta.getName()).toBe('New dashboard');
      });
    });

    describe('when canCreateNewDashboard is false', () => {
      beforeEach(() => {
        router = createRouter(base, breadcrumbState, {
          canCreateNewDashboard: false,
        });
      });

      it('does not include the /new route', () => {
        const newDashboardRoute = getNewRoute();

        expect(newDashboardRoute).toBeUndefined();
      });
    });
  });
});
