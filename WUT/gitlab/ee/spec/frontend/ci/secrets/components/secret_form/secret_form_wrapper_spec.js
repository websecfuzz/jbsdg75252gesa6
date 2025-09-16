import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import getProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import CiEnvironmentsDropdown, {
  ENVIRONMENT_FETCH_ERROR,
  getGroupEnvironments,
  getProjectEnvironments,
} from '~/ci/common/private/ci_environments_dropdown';
import { ENTITY_GROUP, ENTITY_PROJECT } from 'ee/ci/secrets/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSecretDetailsQuery from 'ee/ci/secrets/graphql/queries/get_secret_details.query.graphql';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import {
  mockGroupEnvironments,
  mockProjectEnvironments,
  mockProjectBranches,
  mockProjectSecretQueryResponse,
} from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretFormWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockGroupEnvQuery;
  let mockProjectEnvQuery;
  let mockProjectBranchesResponse;
  let mockSecretQuery;

  const defaultProps = {
    entity: ENTITY_GROUP,
    fullPath: 'full/path/to/entity',
    isEditing: false,
  };

  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findEnvironmentsLoadingIcon = () => findEnvironmentsDropdown().findComponent(GlLoadingIcon);
  const findSecretLoadingIcon = () => wrapper.findByTestId('secret-loading-icon');
  const findPageTitle = () => wrapper.find('h1').text();
  const findSecretForm = () => wrapper.findComponent(SecretForm);

  const createComponent = async ({
    props = {},
    stubs = {},
    isLoading = false,
    mountFn = shallowMountExtended,
  } = {}) => {
    const handlers = [
      [getGroupEnvironments, mockGroupEnvQuery],
      [getProjectEnvironments, mockProjectEnvQuery],
      [getProjectBranches, mockProjectBranchesResponse],
      [getSecretDetailsQuery, mockSecretQuery],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretFormWrapper, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs,
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  beforeEach(() => {
    mockGroupEnvQuery = jest.fn().mockResolvedValue(mockGroupEnvironments);
    mockProjectEnvQuery = jest.fn().mockResolvedValue(mockProjectEnvironments);
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
    mockSecretQuery = jest.fn().mockResolvedValue(mockProjectSecretQueryResponse());
  });

  describe('create form', () => {
    beforeEach(() => {
      createComponent({ props: { isEditing: false } });
    });

    it('shows create form', () => {
      expect(findPageTitle()).toBe('New secret');
    });

    it('passes correct props to secret form', () => {
      expect(findSecretForm().props()).toMatchObject({
        isEditing: false,
        secretData: null,
      });
    });
  });

  describe('edit form', () => {
    beforeEach(async () => {
      createComponent({ props: { isEditing: true, secretName: 'SECRET_KEY' } });

      await nextTick();
    });

    it('shows edit secret form', () => {
      expect(findPageTitle()).toBe('Edit SECRET_KEY');
    });

    it('shows loading icon while secret is being fetched', async () => {
      createComponent({ isLoading: true, props: { isEditing: true, secretName: 'SECRET_KEY' } });

      await nextTick();

      expect(findSecretLoadingIcon().exists()).toBe(true);
    });

    it('passes correct props to secret form', () => {
      expect(findSecretForm().props()).toMatchObject({
        isEditing: true,
        secretData: {
          branch: 'main',
          description: 'This is a secret',
          environment: 'staging',
          name: 'APP_PWD',
        },
      });
    });
  });

  describe('environments dropdown', () => {
    it('uses group environments query for group secrets app', async () => {
      await createComponent({
        props: { entity: ENTITY_GROUP },
        stubs: { SecretForm, CiEnvironmentsDropdown },
      });

      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(0);
      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(1);

      expect(findEnvironmentsDropdown().props('environments')).toEqual([
        'group_env_development',
        'group_env_production',
        'group_env_staging',
      ]);
    });

    it('uses project environments query for project secrets app', async () => {
      await createComponent({
        props: { entity: ENTITY_PROJECT },
        stubs: { SecretForm, CiEnvironmentsDropdown },
      });

      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(0);
      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(1);

      expect(findEnvironmentsDropdown().props('environments')).toEqual([
        'project_env_development',
        'project_env_production',
        'project_env_staging',
      ]);
    });

    describe('while query is being fetched', () => {
      it('shows a loading icon', async () => {
        await createComponent({ isLoading: true, mountFn: mountExtended });

        expect(findEnvironmentsLoadingIcon().exists()).toBe(true);
      });
    });

    describe('when query is successful', () => {
      beforeEach(async () => {
        await createComponent({ isLoading: false, mountFn: mountExtended });
      });

      it('does not show a loading icon', () => {
        expect(findEnvironmentsLoadingIcon().exists()).toBe(false);
      });

      it('does not call createAlert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('query is called with the correct variables', () => {
        expect(mockGroupEnvQuery).toHaveBeenLastCalledWith({
          first: 30,
          fullPath: defaultProps.fullPath,
          search: '',
        });
      });
    });

    describe('when query is unsuccessful', () => {
      beforeEach(async () => {
        mockGroupEnvQuery.mockRejectedValue();
        await createComponent({ isLoading: false });
      });

      it('calls createAlert with the expected error message', () => {
        expect(createAlert).toHaveBeenCalledWith({ message: ENVIRONMENT_FETCH_ERROR });
      });
    });

    it('refetches environments when search term is present', async () => {
      await createComponent();

      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(1);
      expect(mockGroupEnvQuery).toHaveBeenCalledWith(expect.objectContaining({ search: '' }));

      await findSecretForm().vm.$emit('search-environment', 'staging');

      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(2);
      expect(mockGroupEnvQuery).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'staging' }),
      );
    });
  });
});
