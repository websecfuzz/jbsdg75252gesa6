import { shallowMount } from '@vue/test-utils';
import VueRouter from 'vue-router';
import Vue from 'vue';
import { GlBreadcrumb } from '@gitlab/ui';
import AnalyticsDashboardsBreadcrumbs from 'ee/analytics/analytics_dashboards/components/analytics_dashboards_breadcrumbs.vue';
import createRouter from 'ee/analytics/analytics_dashboards/router';

describe('AnalyticsDashboardsBreadcrumbs', () => {
  const base = '/dashboard';
  const breadcrumbState = {
    name: '',
  };

  const rootBreadcrumb = {
    text: 'Analytics dashboards',
    to: '/',
  };

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let router;

  Vue.use(VueRouter);

  const findBreadcrumbs = () => wrapper.findComponent(GlBreadcrumb);

  const createWrapper = (props = {}) => {
    router = createRouter(base, breadcrumbState);

    wrapper = shallowMount(AnalyticsDashboardsBreadcrumbs, {
      router,
      propsData: { staticBreadcrumbs: [], ...props },
    });
  };

  describe('when mounted', () => {
    afterEach(() => {
      breadcrumbState.name = '';
    });

    beforeEach(() => {
      createWrapper();
    });

    it('should render only the root breadcrumb when on the root route', async () => {
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

      expect(findBreadcrumbs().props('items')).toStrictEqual([rootBreadcrumb]);
    });

    it('should render only the root breadcrumb when the dashboard is unknown', async () => {
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

      expect(findBreadcrumbs().props('items')).toStrictEqual([rootBreadcrumb]);
    });

    it('should render the root and dashboard breadcrumbs when on a dashboard', async () => {
      breadcrumbState.name = 'Test dashboard 1';

      await router.push('/test-dashboard-1');

      expect(findBreadcrumbs().props('items')).toStrictEqual([
        rootBreadcrumb,
        {
          text: 'Test dashboard 1',
          to: undefined,
        },
      ]);
    });

    it('should render the root and the static route when the user visits', async () => {
      await router.push('/data-explorer');

      expect(findBreadcrumbs().props('items')).toStrictEqual([
        rootBreadcrumb,
        {
          text: 'Data explorer',
          to: undefined,
        },
      ]);
    });

    it('should disable auto-resize behavior', () => {
      expect(findBreadcrumbs().props('autoResize')).toEqual(false);
    });
  });

  it('should render the static breadcrumbs', async () => {
    const staticBreadcrumb = { text: 'Static breadcrumb', href: '/static' };
    createWrapper({
      staticBreadcrumbs: [staticBreadcrumb],
    });
    await router.push('/data-explorer');

    expect(findBreadcrumbs().props('items')).toStrictEqual([
      staticBreadcrumb,
      rootBreadcrumb,
      {
        text: 'Data explorer',
        to: undefined,
      },
    ]);
  });
});
