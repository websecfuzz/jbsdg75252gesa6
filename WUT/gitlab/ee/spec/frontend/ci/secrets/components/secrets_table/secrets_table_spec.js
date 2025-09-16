import {
  GlButton,
  GlDisclosureDropdownItem,
  GlEmptyState,
  GlKeysetPagination,
  GlTableLite,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { PAGE_SIZE } from 'ee/ci/secrets/constants';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
import getProjectSecrets from 'ee/ci/secrets/graphql/queries/get_project_secrets.query.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import { mockEmptySecrets, mockProjectSecretsData } from '../../mock_data';

Vue.use(VueApollo);

describe('SecretsTable component', () => {
  let wrapper;
  let apolloProvider;
  let mockProjectSecretsResponse;
  let mockSecretManagerStatus;

  const findDeleteModal = () => wrapper.findComponent(SecretDeleteModal);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findEmptyStateButton = () => findEmptyState().findComponent(GlButton);
  const findNewSecretButton = () => wrapper.findByTestId('new-secret-button');
  const findSecretsTable = () => wrapper.findComponent(GlTableLite);
  const findSecretsTableRows = () => findSecretsTable().find('tbody').findAll('tr');
  const findSecretDetailsLink = () => wrapper.findByTestId('secret-details-link');
  const findSecretActionsCell = () => wrapper.findComponent(SecretActionsCell);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const findDeleteButton = (index) =>
    wrapper
      .findAllComponents(SecretActionsCell)
      .at(index)
      .findAllComponents(GlDisclosureDropdownItem)
      .at(1)
      .find('button');

  const createComponent = async ({ props } = {}) => {
    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [getProjectSecrets, mockProjectSecretsResponse],
    ];
    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsTable, {
      propsData: {
        fullPath: `path/to/project`,
        ...props,
      },
      apolloProvider,
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });

    await waitForPromises();
  };

  const mockPaginatedProjectSecrets = ({
    offset = 0,
    limit = PAGE_SIZE,
    startCursor = null,
    endCursor = null,
  } = {}) => ({
    data: {
      projectSecrets: {
        edges: mockProjectSecretsData,
        nodes: mockProjectSecretsData.slice(offset, offset + limit),
        pageInfo: {
          endCursor,
          hasNextPage: Boolean(endCursor),
          hasPreviousPage: Boolean(startCursor),
          startCursor,
          __typename: 'PageInfo',
        },
        __typename: 'ProjectSecretConnection',
      },
    },
  });

  beforeEach(() => {
    mockProjectSecretsResponse = jest.fn();
    mockSecretManagerStatus = jest.fn();

    mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockPaginatedProjectSecrets());
  });

  afterEach(() => {
    apolloProvider = null;
  });

  describe('project secrets table', () => {
    const secret = mockProjectSecretsData[0].node;

    beforeEach(async () => {
      await createComponent();
    });

    it('does not show the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('shows a link to the new secret page', () => {
      expect(findNewSecretButton().props('to')).toBe('new');
    });

    it('renders a table of secrets', () => {
      expect(findSecretsTable().exists()).toBe(true);
      expect(findSecretsTableRows()).toHaveLength(mockProjectSecretsData.length);
    });

    it('shows the secret name as a link to the secret details', () => {
      expect(findSecretDetailsLink().text()).toBe(secret.name);
      expect(findSecretDetailsLink().props('to')).toMatchObject({
        name: 'details',
        params: { secretName: secret.name },
      });
    });

    it('passes correct props to actions cell', () => {
      expect(findSecretActionsCell().props()).toMatchObject({
        secretName: secret.name,
      });
    });

    it('hides the delete secret modal', () => {
      expect(findDeleteModal().props('showModal')).toBe(false);
    });
  });

  describe('when there are no secrets', () => {
    beforeEach(async () => {
      mockProjectSecretsResponse = jest.fn().mockResolvedValue(mockEmptySecrets);
      await createComponent();
    });

    it('shows empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findSecretsTable().exists()).toBe(false);
    });

    it('renders link to secret form', () => {
      expect(findEmptyStateButton().attributes('href')).toBe('new');
    });
  });

  describe('pagination', () => {
    it.each`
      startCursor | endCursor | description          | paginationShouldExist
      ${'MQ'}     | ${'NQ'}   | ${'renders'}         | ${true}
      ${'MQ'}     | ${null}   | ${'renders'}         | ${true}
      ${null}     | ${'NQ'}   | ${'renders'}         | ${true}
      ${null}     | ${null}   | ${'does not render'} | ${false}
    `(
      '$description when there are startCursor = $startCursor and endCursor = $endCursor',
      async ({ startCursor, endCursor, paginationShouldExist }) => {
        mockProjectSecretsResponse.mockResolvedValue(
          mockPaginatedProjectSecrets({
            startCursor,
            endCursor,
          }),
        );

        await createComponent();

        expect(findPagination().exists()).toBe(paginationShouldExist);

        if (paginationShouldExist) {
          expect(findPagination().props('startCursor')).toBe(startCursor);
          expect(findPagination().props('endCursor')).toBe(endCursor);
          expect(findPagination().props('hasPreviousPage')).toBe(Boolean(startCursor));
          expect(findPagination().props('hasNextPage')).toBe(Boolean(endCursor));
        }
      },
    );

    it('calls query with the correct parameters when moving between pages', async () => {
      // initial call
      mockProjectSecretsResponse.mockResolvedValue(
        mockPaginatedProjectSecrets({
          startCursor: null,
          endCursor: 'Mw',
        }),
      );

      await createComponent({ props: { pageSize: 3 } });

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        projectPath: 'path/to/project',
        limit: 3,
      });

      // next page
      mockProjectSecretsResponse.mockResolvedValue(
        mockPaginatedProjectSecrets({
          startCursor: 'MQ',
          endCursor: 'NA',
        }),
      );

      findPagination().vm.$emit('next');
      await waitForPromises();
      await nextTick();

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        after: 'Mw',
        before: null,
        projectPath: 'path/to/project',
        limit: 3,
      });

      // previous page
      findPagination().vm.$emit('prev');
      await waitForPromises();
      await nextTick();

      expect(mockProjectSecretsResponse).toHaveBeenCalledWith({
        after: null,
        before: 'MQ',
        projectPath: 'path/to/project',
        limit: 3,
      });
    });
  });

  describe('delete secret modal', () => {
    describe('when deleting a secret', () => {
      beforeEach(async () => {
        await createComponent();

        findDeleteButton(0).trigger('click');
        await nextTick();
      });

      it('shows delete modal when clicking on "Delete" action', () => {
        expect(findDeleteModal().props('showModal')).toBe(true);
      });

      it('refetches secrets and hides modal when secret is deleted', async () => {
        expect(mockProjectSecretsResponse).toHaveBeenCalledTimes(1);

        findDeleteModal().vm.$emit('refetch-secrets');
        await nextTick();

        expect(findDeleteModal().props('showModal')).toBe(false);
        expect(mockProjectSecretsResponse).toHaveBeenCalledTimes(2);
      });
    });

    describe('when re-opening the modal', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('resets the secret name', async () => {
        findDeleteButton(0).trigger('click');
        await nextTick();

        expect(findDeleteModal().props('secretName')).toBe('SECRET_1');

        findDeleteModal().vm.$emit('hide');
        findDeleteButton(1).trigger('click');
        await nextTick();

        expect(findDeleteModal().props('secretName')).toBe('SECRET_2');
      });
    });
  });
});
