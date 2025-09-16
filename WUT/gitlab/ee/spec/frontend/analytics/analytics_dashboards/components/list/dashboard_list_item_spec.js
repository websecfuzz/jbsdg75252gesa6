import { GlIcon, GlTruncateText, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { nextTick } from 'vue';
import { visitUrl } from '~/lib/utils/url_utility';
import DashboardListItem from 'ee/analytics/analytics_dashboards/components/list/dashboard_list_item.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import {
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
  mockInvalidDashboardErrors,
} from '../../mock_data';

jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api');

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const { nodes } = TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards;
const USER_DEFINED_DASHBOARD = nodes.find((dashboard) => dashboard.userDefined);
const BUILT_IN_DASHBOARD = nodes.find((dashboard) => !dashboard.userDefined);
const REDIRECTED_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  redirect: true,
};
const BETA_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  status: 'beta',
};
const INVALID_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  errors: mockInvalidDashboardErrors,
};

describe('DashboardsListItem', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBuiltInBadge = () => wrapper.findByTestId('dashboard-by-gitlab');
  const findListItem = () => wrapper.findByTestId('dashboard-list-item');
  const findRedirectLink = () => wrapper.findByTestId('dashboard-redirect-link');
  const findRouterLink = () => wrapper.findByTestId('dashboard-router-link');
  const findDescriptionTruncate = () => wrapper.findComponent(GlTruncateText);
  const findStatusBadge = () => wrapper.findByTestId('dashboard-status-badge');
  const findErrorsBadge = () => wrapper.findByTestId('dashboard-errors-badge');
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureDropdownItem = (index) =>
    wrapper.findAllComponents(GlDisclosureDropdownItem).at(index).find('button');

  const $router = {
    push: jest.fn(),
  };

  const createWrapper = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(DashboardListItem, {
      propsData: {
        showUserActions: true,
        ...props,
      },
      stubs: {
        RouterLink: true,
      },
      mocks: {
        $router,
      },
    });
  };

  describe('by default', () => {
    beforeEach(() => {
      createWrapper({ dashboard: USER_DEFINED_DASHBOARD });
    });

    it('renders the dashboard title', () => {
      expect(findRouterLink().text()).toContain(USER_DEFINED_DASHBOARD.title);
    });

    it('renders the dashboard description', () => {
      expect(findDescriptionTruncate().text()).toContain(USER_DEFINED_DASHBOARD.description);
    });

    it('renders the dashboard icon', () => {
      expect(findIcon().props()).toMatchObject({
        name: 'dashboard',
        size: 16,
      });
    });

    it('renders the disclosure dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        toggleText: 'More actions',
        textSrOnly: true,
        category: 'tertiary',
        icon: 'ellipsis_v',
        items: [
          {
            name: 'More actions',
            items: [
              {
                text: 'Clone',
                icon: 'duplicate',
                action: expect.any(Function),
              },
            ],
          },
        ],
      });
    });

    it('does not render the built in label', () => {
      expect(findBuiltInBadge().exists()).toBe(false);
    });

    it('does not render a status badge', () => {
      expect(findStatusBadge().exists()).toBe(false);
    });

    it('does not render errors badge', () => {
      expect(findErrorsBadge().exists()).toBe(false);
    });

    it('routes to the dashboard when a list item is clicked', async () => {
      await findListItem().trigger('click');

      expect($router.push).toHaveBeenCalledWith(USER_DEFINED_DASHBOARD.slug);
    });
  });

  describe('with a built in dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: BUILT_IN_DASHBOARD });
    });

    it('renders the dashboard badge', () => {
      expect(findBuiltInBadge().text()).toBe('Created by GitLab');
    });
  });

  describe('with a redirected dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: REDIRECTED_DASHBOARD });
    });

    it('renders the dashboard title', () => {
      expect(findRedirectLink().text()).toContain(REDIRECTED_DASHBOARD.title);
    });

    it('redirects to the dashboard when the list item is clicked', async () => {
      await findListItem().trigger('click');

      expect(visitUrl).toHaveBeenCalledWith(expect.stringContaining(REDIRECTED_DASHBOARD.slug));
    });
  });

  describe('with a beta dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: BETA_DASHBOARD });
    });

    it('renders the `Beta` badge', () => {
      expect(findStatusBadge().text()).toBe('Beta');
    });
  });

  describe('with an experiment dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: { ...BETA_DASHBOARD, status: 'experiment' } });
    });

    it('renders the `Experiment` badge', () => {
      expect(findStatusBadge().text()).toBe('Experiment');
    });
  });

  describe('with an invalid dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: INVALID_DASHBOARD });
    });

    it('renders the errors badge', () => {
      expect(findErrorsBadge().props()).toMatchObject({
        icon: 'error',
        iconSize: 'sm',
        variant: 'danger',
      });
      expect(findErrorsBadge().text()).toBe('Contains errors');
    });
  });

  describe('when showUserActions is false', () => {
    beforeEach(() => {
      createWrapper({ dashboard: USER_DEFINED_DASHBOARD, showUserActions: false });
    });

    it('does not render the disclosure dropdown', () => {
      expect(findDropdown().exists()).toBe(false);
    });

    it('routes to the dashboard when a list item is clicked', async () => {
      await findListItem().trigger('click');

      expect($router.push).toHaveBeenCalledWith(USER_DEFINED_DASHBOARD.slug);
    });

    describe('with a redirected dashboard', () => {
      beforeEach(() => {
        createWrapper({ dashboard: REDIRECTED_DASHBOARD, showUserActions: false });
      });

      it('redirects to the dashboard when the list item is clicked', async () => {
        await findListItem().trigger('click');

        expect(visitUrl).toHaveBeenCalledWith(expect.stringContaining(REDIRECTED_DASHBOARD.slug));
      });
    });
  });

  describe('when the clone action is clicked', () => {
    beforeEach(async () => {
      createWrapper({ dashboard: USER_DEFINED_DASHBOARD }, mountExtended);

      await nextTick();

      return findDisclosureDropdownItem(0).trigger('click');
    });

    it('emits a "clone" event with the dashboard slug', () => {
      expect(wrapper.emitted('clone')).toStrictEqual([[USER_DEFINED_DASHBOARD.slug]]);
    });
  });
});
