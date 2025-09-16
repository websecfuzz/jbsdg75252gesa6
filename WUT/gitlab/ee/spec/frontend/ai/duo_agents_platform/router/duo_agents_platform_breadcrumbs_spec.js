import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformBreadcrumbs from 'ee/ai/duo_agents_platform/router/duo_agents_platform_breadcrumbs.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTS_PLATFORM_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';

describe('DuoAgentsPlatformBreadcrumbs', () => {
  let wrapper;

  const defaultProps = {
    staticBreadcrumbs: [
      {
        text: 'Test Group',
        to: '/groups/test-group',
      },
      {
        text: 'Test Project',
        to: '/test-group/test-project',
      },
    ],
  };

  const createWrapper = (props = {}, routeOptions = {}) => {
    wrapper = shallowMount(DuoAgentsPlatformBreadcrumbs, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $route: {
          name: AGENTS_PLATFORM_INDEX_ROUTE,
          params: {},
          ...routeOptions,
        },
      },
      stubs: {
        GlBreadcrumb,
      },
    });
  };

  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);
  const getBreadcrumbItems = () => findBreadcrumb().props('items');

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the breadcrumb component', () => {
      expect(findBreadcrumb().exists()).toBe(true);
    });

    it('passes auto-resize as false to breadcrumb', () => {
      expect(findBreadcrumb().props('autoResize')).toBe(false);
    });
  });

  describe('breadcrumb items on index route', () => {
    beforeEach(() => {
      createWrapper({}, { name: AGENTS_PLATFORM_INDEX_ROUTE });
    });

    it('includes current page as last item without link', () => {
      const items = getBreadcrumbItems();

      expect(items[items.length - 1]).toEqual({
        text: 'Agent sessions',
        to: undefined,
      });
    });

    it('has correct number of items', () => {
      const items = getBreadcrumbItems();
      expect(items).toHaveLength(4); // 2 static routes + Automate + Agent Sessions
    });
  });

  describe('breadcrumb items on new route', () => {
    beforeEach(() => {
      createWrapper(
        {},
        {
          name: AGENTS_PLATFORM_NEW_ROUTE,
        },
      );
    });

    it('includes root route with Vue router navigation', () => {
      const items = getBreadcrumbItems();
      expect(items[2].text).toBe('Automate');
      expect(items[2].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);

      expect(items[3].text).toBe('Agent sessions');
      expect(items[3].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);
    });

    it('includes new page as last item without link', () => {
      const items = getBreadcrumbItems();

      expect(items[items.length - 1]).toEqual({
        text: 'New',
        to: undefined,
      });
    });
  });

  describe('breadcrumb items on show route', () => {
    beforeEach(() => {
      createWrapper(
        {},
        {
          name: AGENTS_PLATFORM_SHOW_ROUTE,
          params: { id: 'test-agent-id' },
        },
      );
    });

    it('includes root route with Vue router navigation', () => {
      const items = getBreadcrumbItems();

      expect(items[2].text).toBe('Automate');
      expect(items[2].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);

      expect(items[3].text).toBe('Agent sessions');
      expect(items[3].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);
    });

    it('includes current agent page as last item without link', () => {
      const items = getBreadcrumbItems();

      expect(items[items.length - 1]).toEqual({
        text: 'test-agent-id',
        to: undefined,
      });
    });

    it('has correct number of items', () => {
      const items = getBreadcrumbItems();
      expect(items).toHaveLength(5); // 2 static routes + root route + current agent
    });
  });

  describe('Show route without ID', () => {
    beforeEach(() => {
      createWrapper(
        {},
        {
          name: AGENTS_PLATFORM_SHOW_ROUTE,
          params: {},
        },
      );
    });

    it('does not include agent route', () => {
      const items = getBreadcrumbItems();

      expect(items).toHaveLength(4); // 2 static routes + root routes + sh

      expect(items[2].text).toBe('Automate');
      expect(items[2].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);

      expect(items[3].text).toBe('Agent sessions');
      expect(items[3].to.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);
    });
  });
});
