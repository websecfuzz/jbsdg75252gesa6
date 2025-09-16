import { shallowMount } from '@vue/test-utils';
import VueRouter from 'vue-router';
import Vue from 'vue';
import { GlBreadcrumb } from '@gitlab/ui';
import SecretsBreadcrumbs from 'ee/ci/secrets/components/secrets_breadcrumbs.vue';
import createRouter from 'ee/ci/secrets/router';
import { INDEX_ROUTE_NAME, DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';

const defaultProps = {
  groupId: '1',
  groupPath: '/path/to/group',
};

describe('SecretsBreadcrumbs', () => {
  const rootBreadcrumb = {
    text: 'Secrets',
    to: { name: INDEX_ROUTE_NAME },
  };
  const secretDetailsBreadcrumb = {
    text: 'project_secret_1',
    to: { name: DETAILS_ROUTE_NAME },
  };

  let wrapper;
  let router;

  Vue.use(VueRouter);

  const findBreadcrumbs = () => wrapper.findComponent(GlBreadcrumb);

  const createWrapper = (props = { staticBreadcrumbs: [] }) => {
    router = createRouter('/-/secrets', defaultProps);

    wrapper = shallowMount(SecretsBreadcrumbs, {
      router,
      propsData: props,
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  it('should render only the root breadcrumb when on root route', () => {
    expect(findBreadcrumbs().props('items')).toStrictEqual([rootBreadcrumb]);
  });

  it.each`
    routeName             | route
    ${'New secret'}       | ${'/new'}
    ${'project_secret_1'} | ${'/project_secret_1/details'}
  `(
    'should render the root and $routeName breadcrumbs when on $route',
    async ({ routeName, route }) => {
      await router.push(route);

      expect(findBreadcrumbs().props('items')).toStrictEqual([
        rootBreadcrumb,
        expect.objectContaining({
          text: routeName,
        }),
      ]);
    },
  );

  it.each`
    routeName | route
    ${'Edit'} | ${'/project_secret_1/edit'}
  `(
    'should render the root, secret details, and $routeName breadcrumbs when on $route',
    async ({ routeName, route }) => {
      await router.push(route);

      expect(findBreadcrumbs().props('items')).toStrictEqual([
        rootBreadcrumb,
        secretDetailsBreadcrumb,
        {
          text: routeName,
          to: undefined,
        },
      ]);
    },
  );

  it('should disable auto-resize behavior', () => {
    expect(findBreadcrumbs().props('autoResize')).toEqual(false);
  });

  it('should include static breadcrumbs before dynamic breadcrumbs', () => {
    const staticBreadcrumbs = [
      { text: 'Static 1', href: '/static1' },
      { text: 'Static 2', href: '/static2' },
    ];

    createWrapper({ staticBreadcrumbs });

    expect(findBreadcrumbs().props('items')).toStrictEqual([...staticBreadcrumbs, rootBreadcrumb]);
  });
});
