import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlLoadingIcon,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ProjectToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search_v2/components/search_suggestion.vue';
import { DASHBOARD_TYPE_GROUP } from 'ee/security_dashboard/constants';
import getProjects from 'ee/security_dashboard/graphql/queries/group_projects.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

const TEST_PROJECTS = [
  {
    id: 'gid://gitlab/Project/1',
    name: 'GitLab Community Edition',
    fullPath: 'gitlab-org/gitlab-ce',
    avatarUrl: 'https://gitlab.com/uploads/-/system/project/avatar/1/logo-extra-whitespace.png',
    rawId: 1,
  },
  {
    id: 'gid://gitlab/Project/2',
    name: 'GitLab Enterprise Edition',
    fullPath: 'gitlab-org/gitlab-ee',
    avatarUrl: 'https://gitlab.com/uploads/-/system/project/avatar/2/logo-extra-whitespace.png',
    rawId: 2,
  },
];

const TEST_GROUP = 'secure';

describe('ee/security_dashboard/components/shared/filtered_search_v2/tokens/project_token.vue', () => {
  let wrapper;
  let handlerMocks;

  const createMockApolloProvider = ({ handlers = {} } = {}) => {
    const defaultHandlers = {
      getProjectHandler: jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            __typename: 'Group',
            projects: {
              edges: TEST_PROJECTS.map((project) => ({
                __typename: 'ProjectEdge',
                node: {
                  ...project,
                  __typename: 'Project',
                },
              })),
              pageInfo: {
                endCursor: 'eyJpZCI6IjE0In0',
                hasNextPage: false,
                __typename: 'PageInfo',
              },
              __typename: 'ProjectConnection',
            },
          },
        },
      }),
    };

    handlerMocks = { ...defaultHandlers, ...handlers };

    const requestHandlers = [[getProjects, handlerMocks.getProjectHandler]];

    return createMockApollo(requestHandlers);
  };

  const createComponent = ({
    propsData = {},
    handlers = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ProjectToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      provide: {
        groupFullPath: TEST_GROUP,
        dashboardType: DASHBOARD_TYPE_GROUP,
      },
      stubs: {
        SearchSuggestion,
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `
              <div>
                  <div data-testid="slot-view">
                      <slot name="view"></slot>
                  </div>
                  <div data-testid="slot-suggestions">
                      <slot name="suggestions"></slot>
                  </div>
              </div>`,
        }),
      },
      apolloProvider: createMockApolloProvider({
        handlers,
      }),
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findSlotView = () => wrapper.findByTestId('slot-view');
  const findSlotSuggestions = () => wrapper.findByTestId('slot-suggestions');

  const searchForProject = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };

  const selectProject = (project) => {
    findFilteredSearchToken().vm.$emit('select', project.rawId);
    return nextTick();
  };

  const findFirstSearchSuggestionIcon = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);

  describe('when the component is initially rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows a loading indicator while fetching the list of projects', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('fetches the list of projects', () => {
      expect(handlerMocks.getProjectHandler).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: TEST_GROUP, search: '', pageSize: 100 }),
      );
    });

    it.each([
      { active: true, expectedValue: { data: null } },
      { active: false, expectedValue: { data: [] } },
    ])(
      'passes "$expectedValue" to the search-token when the dropdown is open: "$active"',
      ({ active, expectedValue }) => {
        createComponent({
          propsData: {
            active,
            value: { data: [] },
          },
        });

        expect(findFilteredSearchToken().props('value')).toEqual(expectedValue);
      },
    );
  });

  describe('when value property is not an array', () => {
    beforeEach(() => {
      createComponent({ propsData: { value: { data: '' } } });
    });

    it('still renders', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });
  });

  describe('when the projects have been fetched successfully', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show an error message', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('shows a list of project suggestions', () => {
      expect(wrapper.findAllComponents(GlFilteredSearchSuggestion)).toHaveLength(
        TEST_PROJECTS.length,
      );
      expect(findSlotSuggestions().text()).toContain(TEST_PROJECTS[0].name);
      expect(findSlotSuggestions().text()).toContain(TEST_PROJECTS[1].name);
    });

    it('fetches projects matching the search term', async () => {
      const TEST_SEARCH_TERM = 'GitLab Community';

      expect(handlerMocks.getProjectHandler).toHaveBeenCalledWith(
        expect.objectContaining({ search: '' }),
      );

      await searchForProject(TEST_SEARCH_TERM);

      expect(handlerMocks.getProjectHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: TEST_SEARCH_TERM }),
      );
    });

    describe('when a user selects projects to be filtered', () => {
      it('displays a check-icon next to the selected project', async () => {
        expect(findFirstSearchSuggestionIcon().classes()).toContain('gl-invisible');

        await selectProject(TEST_PROJECTS[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });

      it('shows a comma seperated list of selected projects', async () => {
        await selectProject(TEST_PROJECTS[0]);
        await selectProject(TEST_PROJECTS[1]);

        expect(findSlotView().text()).toBe(`${TEST_PROJECTS[0].name} +1 more`);
      });
    });
  });

  describe('when there is an error fetching the projects', () => {
    beforeEach(async () => {
      createComponent({
        handlers: {
          getProjectHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
        },
      });

      await waitForPromises();
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching the projects for this group. Please try again later.',
      });
    });
  });
});
