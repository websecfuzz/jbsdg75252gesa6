import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import getProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import SecretBranchesField from 'ee/ci/secrets/components/secret_form/secret_branches_field.vue';
import { mockProjectBranches } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretFormWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockProjectBranchesResponse;

  const { branchNames } = mockProjectBranches.data.project.repository;

  const defaultProps = {
    fullPath: 'full/path/to/entity',
    selectedBranch: '',
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateWildcardButton = () => wrapper.findByTestId('create-wildcard-button');
  const findSearchQueryNote = () => wrapper.findByTestId('search-query-note');

  const createComponent = async ({
    isLoading = false,
    mountFn = shallowMountExtended,
    props = {},
    stubs = {},
  } = {}) => {
    const handlers = [[getProjectBranches, mockProjectBranchesResponse]];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretBranchesField, {
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
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
  });

  describe('while query is loading', () => {
    beforeEach(() => {
      createComponent({ loading: true });
    });

    it('shows loading icon', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });
  });

  describe('when query is successful', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('does not show loading icon', () => {
      expect(findDropdown().props('loading')).toBe(false);
    });

    it('renders search query note', () => {
      expect(findSearchQueryNote().text()).toBe(
        'Enter a search query to find more branches, or use * to create a wildcard.',
      );
    });

    it('loads fetched branch names as dropdown items', () => {
      expect(findDropdown().props('items')).toStrictEqual([
        { text: 'dev', value: 'dev' },
        { text: 'main', value: 'main' },
        { text: 'production', value: 'production' },
        { text: 'staging', value: 'staging' },
      ]);
    });
  });

  describe('when query is unsuccessful', () => {
    beforeEach(async () => {
      mockProjectBranchesResponse = jest.fn().mockRejectedValue();
      await createComponent();
    });

    it('renders alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while fetching branches.',
      });
    });
  });

  describe('when selecting a branch', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('emits `select-branch` when a branch is clicked', () => {
      findDropdown().vm.$emit('select', 'main');

      expect(wrapper.emitted('select-branch')).toEqual([['main']]);
    });
  });

  describe('when search results are empty', () => {
    describe('with wildcard character', () => {
      beforeEach(async () => {
        createComponent();

        findDropdown().vm.$emit('search', 'stable/*');
        await nextTick();
      });

      it('renders create wildcard button if branch list does not contain search term', () => {
        expect(findCreateWildcardButton().exists()).toBe(true);
        expect(findCreateWildcardButton().text()).toBe('Create wildcard: stable/*');
      });

      it('sets new wildcard branch as the selected branch when button is clicked', () => {
        findCreateWildcardButton().vm.$emit('click', 'stable/*');

        expect(wrapper.emitted('select-branch')).toStrictEqual([['stable/*']]);
      });
    });

    describe('without wildcard character', () => {
      beforeEach(async () => {
        createComponent();

        findDropdown().vm.$emit('search', 'stable/');
        await nextTick();
      });

      it('does not render create wildcard button', () => {
        expect(findCreateWildcardButton().exists()).toBe(false);
      });
    });
  });

  describe('rendering wildcard as selected branch', () => {
    beforeEach(async () => {
      createComponent({ props: { selectedBranch: 'stable' } });

      findDropdown().vm.$emit('search', 'stable');
      await nextTick();
    });

    it('includes new branch in search if it matches search term', async () => {
      findDropdown().vm.$emit('search', 'stable');
      await nextTick();

      expect(findDropdown().props('items')).toHaveLength(branchNames.length + 1);
      expect(findDropdown().props('items')[0].text).toBe('stable');
    });

    it('excludes new branch in search if it does not match the search term', async () => {
      findDropdown().vm.$emit('search', 'different-branch');
      await nextTick();

      expect(findDropdown().props('items')).toHaveLength(branchNames.length);
    });
  });
});
