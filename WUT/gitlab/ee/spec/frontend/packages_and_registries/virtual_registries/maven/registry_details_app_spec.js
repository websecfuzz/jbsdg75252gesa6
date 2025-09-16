import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getMavenVirtualRegistryUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_virtual_registry_upstreams.query.graphql';
import createUpstreamRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_upstream_registry.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MavenRegistriesDetailsApp from 'ee/packages_and_registries/virtual_registries/maven/registry_details_app.vue';
import MavenRegistryDetails from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_item.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { groupVirtualRegistry } from '../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

const mockGroupVirtualRegistry = {
  data: {
    ...groupVirtualRegistry,
  },
};

const defaultProvide = {
  groupPath: 'flightjs',
  registry: {
    id: '1',
    name: 'Registry 1',
    description: 'Maven Registry',
  },
  registryEditPath: '/groups/flightjs/-/virtual_registries/maven/1/edit',
  editUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id/edit',
  showUpstreamPathTemplate: '/groups/flightjs/-/virtual_registries/maven/upstreams/:id',
};

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const mockError = new Error('GraphQL error');

  const findMavenRegistryDetails = () => wrapper.findComponent(MavenRegistryDetails);
  const findUpstreamRegistryItems = () => wrapper.findAllComponents(RegistryUpstreamItem);

  const groupMavenRegistriesHandler = jest.fn().mockResolvedValue(mockGroupVirtualRegistry);
  const createUpstreamSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      mavenUpstreamCache: {
        errors: [],
      },
    },
  });
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({ handlers = [] } = {}) => {
    wrapper = mountExtended(MavenRegistriesDetailsApp, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        ...defaultProvide,
      },
    });
  };

  describe('loading state', () => {
    it('displays a loading state', () => {
      createComponent();

      expect(findMavenRegistryDetails().text()).toContain('No upstreams yet');
    });
  });

  describe('upstreams list', () => {
    it('displays the upstream registries currently available', async () => {
      const upstreamsLength =
        groupVirtualRegistry.group.mavenVirtualRegistries.nodes[0].upstreams.length;

      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, groupMavenRegistriesHandler]],
      });

      await waitForPromises();

      expect(findMavenRegistryDetails().exists()).toBe(true);
      expect(findUpstreamRegistryItems()).toHaveLength(upstreamsLength);
    });
  });

  describe('When creating a new upstream', () => {
    it('creates a new upstream', async () => {
      const event = {
        name: 'Maven upstream 7',
        url: 'https://repo.maven.apache.org/maven2',
        description: '',
        username: '',
        password: '',
        cacheValidityHours: 24,
      };

      createComponent({
        handlers: [
          [getMavenVirtualRegistryUpstreamsQuery, groupMavenRegistriesHandler],
          [createUpstreamRegistryMutation, createUpstreamSuccessHandler],
        ],
      });

      await findMavenRegistryDetails().vm.$emit('createUpstream', event);

      expect(createUpstreamSuccessHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/1',
        ...event,
      });
    });
  });

  describe('with errors', () => {
    it('sends an error to Sentry', async () => {
      createComponent({
        handlers: [[getMavenVirtualRegistryUpstreamsQuery, errorHandler]],
      });

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith({
        component: 'RegistryDetailsRoot',
        error: mockError,
      });
    });
  });
});
