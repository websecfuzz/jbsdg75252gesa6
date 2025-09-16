import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import createRouter from 'ee/ci/secrets/router';
import SecretsApp from 'ee//ci/secrets/components/secrets_app.vue';
import { getMatchedComponents } from '~/lib/utils/vue3compat/vue_router';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import {
  SECRET_MANAGER_STATUS_ACTIVE,
  ENTITY_GROUP,
  ENTITY_PROJECT,
} from 'ee/ci/secrets/constants';
import { secretManagerStatusResponse } from './mock_data';

Vue.use(VueRouter);
Vue.use(VueApollo);
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Secrets router', () => {
  let wrapper;
  let router;
  let apolloProvider;
  const mockSecretManagerStatus = jest
    .fn()
    .mockResolvedValue(secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE));

  const base = '/-/secrets';

  const groupProps = {
    entity: ENTITY_GROUP,
    fullPath: '/path/to/group',
  };

  const projectProps = {
    entity: ENTITY_PROJECT,
    fullPath: '/path/to/project',
  };

  const editRoute = { name: 'edit', params: { secretName: 'SECRET_KEY' } };

  const createSecretsApp = async ({ route, props } = {}) => {
    const handlers = [[getSecretManagerStatusQuery, mockSecretManagerStatus]];

    apolloProvider = createMockApollo(handlers);

    router = createRouter(base, props);
    if (route) {
      await router.push(route);
    }

    wrapper = mountExtended(SecretsApp, {
      router,
      propsData: { ...props },
      data() {
        return {
          secrets: [],
        };
      },
      apolloProvider,
    });

    await waitForPromises();
  };

  it.each`
    path                     | componentNames            | components
    ${'/'}                   | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/?page=2'}            | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/new'}                | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
    ${'/secretName/details'} | ${'SecretDetailsWrapper'} | ${[SecretDetailsWrapper]}
    ${'/secretName/edit'}    | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
  `('uses $componentNames for path "$path"', ({ path, components }) => {
    router = createRouter(base, groupProps);
    const componentsForRoute = getMatchedComponents(router, path);

    expect(componentsForRoute).toStrictEqual(components);
  });

  it.each`
    path                          | redirect
    ${'/secretName'}              | ${'details'}
    ${'/secretName/unknownroute'} | ${'index'}
  `('redirects from $path to $redirect', async ({ path, redirect }) => {
    router = createRouter(base, groupProps);

    await router.push(path);

    expect(router.currentRoute.name).toBe(redirect);
  });

  describe.each`
    entity       | props           | fullPath              | isGroup
    ${'group'}   | ${groupProps}   | ${'/path/to/group'}   | ${true}
    ${'project'} | ${projectProps} | ${'/path/to/project'} | ${false}
  `('$entity secrets form', ({ props, fullPath }) => {
    it('provides the correct props when visiting the index', async () => {
      await createSecretsApp({ route: '/', props });

      expect(wrapper.findComponent(SecretsTable).props()).toMatchObject({
        fullPath,
      });
    });

    it('provides the correct props when visiting the create form', async () => {
      await createSecretsApp({ route: '/new', props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        fullPath,
      });
    });

    it('provides the correct props when visiting the edit form', async () => {
      await createSecretsApp({ route: editRoute, props });

      expect(wrapper.findComponent(SecretFormWrapper).props()).toMatchObject({
        fullPath,
        isEditing: true,
        secretName: 'SECRET_KEY',
      });
    });
  });
});
