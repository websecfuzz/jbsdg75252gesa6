import { shallowMount } from '@vue/test-utils';
import DuoAgentsPlatformApp from 'ee/ai/duo_agents_platform/duo_agents_platform_app.vue';

describe('DuoAgentsPlatformApp', () => {
  let mockRoute;

  let wrapper;

  const createWrapper = (props = {}) => {
    mockRoute = {
      path: '/',
      name: 'agents_platform_index_page',
    };

    return shallowMount(DuoAgentsPlatformApp, {
      propsData: props,
      mocks: {
        $route: mockRoute,
      },
      stubs: {
        RouterView: true,
        KeepAlive: true,
      },
    });
  };

  const findAppContainer = () => wrapper.find('#agents-platform-app');
  const findKeepAliveComponentVue2 = () => wrapper.find('keepalive-stub');
  const findKeepAliveComponentVue3 = () => wrapper.find('keep-alive-stub');

  const findKeepAliveComponent = () => {
    if (findKeepAliveComponentVue2().exists()) {
      return findKeepAliveComponentVue2();
    }

    return findKeepAliveComponentVue3();
  };

  describe('when component is mounted', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('renders the app container', () => {
      expect(findAppContainer().exists()).toBe(true);
    });

    it('renders the router-view component', () => {
      expect(wrapper.html()).toContain('routerview');
    });

    it('renders the keep-alive component with list of components to include', () => {
      expect(findKeepAliveComponent().exists()).toBe(true);
      expect(findKeepAliveComponent().props().include).toEqual(['DuoAgentPlatformIndex']);
    });
  });
});
