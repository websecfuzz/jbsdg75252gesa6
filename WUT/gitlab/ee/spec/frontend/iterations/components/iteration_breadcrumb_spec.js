import { shallowMount } from '@vue/test-utils';
import { GlBreadcrumb, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import IterationBreadcrumb from 'ee/iterations/components/iteration_breadcrumb.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import readCadenceQuery from 'ee/iterations/queries/iteration_cadence.query.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createRouter from 'ee/iterations/router';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);
Vue.use(VueRouter);

describe('Iteration Breadcrumb', () => {
  let router;
  let wrapper;
  let mockApollo;

  const base = '/';
  const permissions = {
    canCreateCadence: true,
    canEditCadence: true,
    canCreateIteration: true,
    canEditIteration: true,
  };
  const cadenceId = 1234;
  const iterationId = 4567;

  const cadenceTitle = 'cadenceTitle';
  const cadenceResponse = {
    data: {
      group: {
        id: '',
        iterationCadences: {
          nodes: [
            {
              __typename: 'IterationCadence',
              title: cadenceTitle,
              id: 'cadenceid',
              automatic: '',
              startDate: '',
              rollOver: '',
              durationInWeeks: '',
              iterationsInAdvance: '',
              description: '',
            },
          ],
        },
      },
    },
  };

  const findBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);

  const waitForApollo = async () => {
    jest.runOnlyPendingTimers();
    await waitForPromises();
  };

  const initRouter = () => {
    router = createRouter({ base, permissions });
  };

  const mountComponent = ({ requestHandlers = [], readCadenceSpy, props = {} } = {}) => {
    mockApollo = createMockApollo([[readCadenceQuery, readCadenceSpy], ...requestHandlers]);

    wrapper = extendedWrapper(
      shallowMount(IterationBreadcrumb, {
        router,
        provide: { groupPath: '' },
        apolloProvider: mockApollo,
        propsData: { staticBreadcrumbs: [], ...props },
      }),
    );
  };

  beforeEach(() => {
    initRouter();
  });

  it('finds glbreadcrumb', async () => {
    mountComponent();
    await waitForApollo();

    expect(findBreadcrumb().exists()).toBe(true);
  });

  describe('when fetching cadence', () => {
    it('renders the GlSkeletonLoader', async () => {
      await router.push({ name: 'editIteration', params: { iterationId: '1', cadenceId: '123' } });
      mountComponent({ readCadenceSpy: jest.fn().mockResolvedValue(cadenceResponse) });

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });
  });

  describe('when not fetching cadence', () => {
    it('does not render the GlSkeletonLoader', () => {
      mountComponent({ readCadenceSpy: jest.fn().mockResolvedValue(cadenceResponse) });

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(false);
    });
  });

  describe('when a user is on a cadence page', () => {
    afterEach(() => {
      router = null;
    });

    it('passes the correct items to GlBreadcrumb', async () => {
      await router.push({ name: 'editIteration', params: { cadenceId, iterationId } });
      mountComponent({ readCadenceSpy: jest.fn().mockResolvedValue(cadenceResponse) });
      await waitForApollo();

      expect(findBreadcrumb().props('items')).toEqual([
        { path: '', text: 'Iteration cadences', to: '/' },
        { path: '1234', text: 'cadenceTitle', to: '/1234' },
        { path: 'iterations', text: 'Iterations', to: `/${cadenceId}/iterations` },
        {
          path: `${iterationId}`,
          text: `${iterationId}`,
          to: `/${cadenceId}/iterations/${iterationId}`,
        },
        { path: 'edit', text: 'Edit', to: `/${cadenceId}/iterations/${iterationId}/edit` },
      ]);
    });

    it('passes the static breadcrumbs to GlBreadcrumb if provided', async () => {
      await router.push({ name: 'editIteration', params: { cadenceId, iterationId } });
      mountComponent({
        readCadenceSpy: jest.fn().mockResolvedValue(cadenceResponse),
        props: {
          staticBreadcrumbs: [{ text: 'Static breadcrumb', href: '/static' }],
        },
      });
      await waitForApollo();

      expect(findBreadcrumb().props('items')).toEqual([
        { text: 'Static breadcrumb', href: '/static' },
        { path: '', text: 'Iteration cadences', to: '/' },
        { path: '1234', text: 'cadenceTitle', to: '/1234' },
        { path: 'iterations', text: 'Iterations', to: `/${cadenceId}/iterations` },
        {
          path: `${iterationId}`,
          text: `${iterationId}`,
          to: `/${cadenceId}/iterations/${iterationId}`,
        },
        { path: 'edit', text: 'Edit', to: `/${cadenceId}/iterations/${iterationId}/edit` },
      ]);
    });
  });

  describe('when cadenceId isnt present', () => {
    it('skips the call to graphql', () => {
      const cadenceSpy = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '', iterationCadences: { nodes: [] } } } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      expect(cadenceSpy).toHaveBeenCalledTimes(0);
    });
  });

  describe('when cadenceId is present', () => {
    it('calls the iteration cadence query', async () => {
      const cadenceSpy = jest
        .fn()
        .mockResolvedValue({ data: { group: { id: '', iterationCadences: { nodes: [] } } } });

      await router.push({ name: 'editIteration', params: { iterationId: '1', cadenceId: '123' } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      expect(cadenceSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('when cadence is present', () => {
    const breadcrumbProps = () => findBreadcrumb().props('items');

    let cadenceSpy;

    beforeEach(() => {
      cadenceSpy = jest.fn().mockResolvedValue(cadenceResponse);
    });

    it('is found in crumb items', async () => {
      await router.push({ name: 'editIteration', params: { cadenceId: '123', iterationId: '1' } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      await waitForPromises();
      expect(breadcrumbProps().some(({ text }) => text === cadenceTitle)).toBe(true);
    });

    it('does not pass a breadcrumb without a title', async () => {
      await router.push({ name: 'index' });

      mountComponent({ readCadenceSpy: cadenceSpy });

      await waitForPromises();

      expect(breadcrumbProps().some(({ text }) => text === '')).toBe(false);
    });
  });

  describe('when cadence is not present', () => {
    it('cadence id found in crumb items', async () => {
      const cadenceSpy = jest.fn().mockResolvedValue({
        data: { group: { id: '', iterationCadences: { nodes: [] } } },
      });

      await router.push({ name: 'editIteration', params: { cadenceId: '123', iterationId: '1' } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      await waitForPromises();

      const breadcrumbProps = findBreadcrumb().props('items');

      expect(breadcrumbProps.some(({ text }) => text === '123')).toBe(true);
    });
  });

  describe('when graphql returns error', () => {
    it('cadence id is found in crumb items', async () => {
      const cadenceSpy = jest.fn().mockResolvedValue({
        data: { group: { id: '', iterationCadences: { nodes: [], errors: ['error'] } } },
      });

      await router.push({ name: 'editIteration', params: { cadenceId: '123', iterationId: '1' } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      await waitForPromises();

      const breadcrumbProps = findBreadcrumb().props('items');

      expect(breadcrumbProps.some(({ text }) => text === '123')).toBe(true);
    });
  });

  describe('when server returns error', () => {
    it('cadence id is found in crumb items', async () => {
      const cadenceSpy = jest.fn().mockResolvedValue({
        data: { group: { id: '', iterationCadences: { nodes: [] }, error: 'error' } },
      });

      await router.push({ name: 'editIteration', params: { cadenceId: '123', iterationId: '1' } });

      mountComponent({ readCadenceSpy: cadenceSpy });

      await waitForPromises();

      const breadcrumbProps = findBreadcrumb().props('items');

      expect(breadcrumbProps.some(({ text }) => text === '123')).toBe(true);
    });
  });
});
