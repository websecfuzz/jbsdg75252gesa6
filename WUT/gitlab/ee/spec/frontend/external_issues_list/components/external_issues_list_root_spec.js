import { GlAlert } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import ExternalIssuesListRoot from 'ee/external_issues_list/components/external_issues_list_root.vue';
import jiraIssuesResolver from 'ee/integrations/jira/issues_list/graphql/resolvers/jira_issues';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  FILTERED_SEARCH_TERM,
  TOKEN_TYPE_LABEL,
} from '~/vue_shared/components/filtered_search_bar/constants';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import { i18n } from '~/issues/list/constants';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';

import {
  mockProvide,
  mockJiraIssues as mockExternalIssues,
  mockJiraIssue4 as mockJiraIssueNoReference,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/vue_shared/issuable/list/constants', () => ({
  DEFAULT_PAGE_SIZE: 2,
  issuableListTabs: jest.requireActual('~/vue_shared/issuable/list/constants').issuableListTabs,
  availableSortOptions: jest.requireActual('~/vue_shared/issuable/list/constants')
    .availableSortOptions,
}));
jest.mock(
  '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue',
  () => 'LabelTokenMock',
);

const resolvedValue = {
  headers: {
    'x-page': 1,
    'x-total': mockExternalIssues.length,
  },
  data: mockExternalIssues,
};

const resolvers = {
  Query: {
    externalIssues: jiraIssuesResolver,
  },
};

function createMockApolloProvider(mockResolvers = resolvers) {
  Vue.use(VueApollo);
  return createMockApollo([], mockResolvers);
}

describe('ExternalIssuesListRoot', () => {
  let wrapper;
  let mock;

  const mockProject = 'ES';
  const mockStatus = 'To Do';
  const mockAuthor = 'Author User';
  const mockAssignee = 'Assignee User';
  const mockLabel = 'ecosystem';
  const mockSearchTerm = 'test issue';
  const expectedParams = {
    with_labels_details: true,
    per_page: 2,
    page: 1,
    sort: 'created_desc',
    state: 'opened',
    project: undefined,
    status: undefined,
    author_username: undefined,
    assignee_username: undefined,
    labels: undefined,
    search: undefined,
  };

  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findAlertMessage = () => findAlert().find('span');
  const createLabelFilterEvent = (data) => ({ type: TOKEN_TYPE_LABEL, value: { data } });
  const createSearchFilterEvent = (data) => ({ type: FILTERED_SEARCH_TERM, value: { data } });

  const expectErrorHandling = (expectedRenderedErrorMessage) => {
    const issuesList = findIssuableList();
    const alert = findAlert();

    expect(issuesList.exists()).toBe(false);

    expect(alert.exists()).toBe(true);
    expect(alert.text()).toBe(expectedRenderedErrorMessage);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
  };

  const createComponent = ({
    mountFn = shallowMount,
    apolloProvider = createMockApolloProvider(),
    provide = mockProvide,
    initialFilterParams = {},
  } = {}) => {
    wrapper = mountFn(ExternalIssuesListRoot, {
      propsData: {
        initialFilterParams,
      },
      provide,
      apolloProvider,
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('while loading', () => {
    it('sets issuesListLoading to `true`', async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(new Promise(() => {}));

      createComponent();
      await nextTick();

      const issuableList = findIssuableList();
      expect(issuableList.props('issuablesLoading')).toBe(true);
    });

    it('calls `axios.get` with `issuesFetchPath` and query params', async () => {
      jest.spyOn(axios, 'get');

      createComponent();
      await waitForPromises();

      expect(axios.get).toHaveBeenCalledWith(
        mockProvide.issuesFetchPath,
        expect.objectContaining({
          params: {
            ...expectedParams,
          },
        }),
      );
    });
  });

  describe('with `initialFilterParams` prop', () => {
    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

      createComponent({
        initialFilterParams: {
          project: mockProject,
          status: mockStatus,
          authorUsername: mockAuthor,
          assigneeUsername: mockAssignee,
          labels: [mockLabel],
          search: mockSearchTerm,
        },
      });
      await waitForPromises();
    });

    it('calls `axios.get` with `issuesFetchPath` and query params', () => {
      expect(axios.get).toHaveBeenCalledWith(
        mockProvide.issuesFetchPath,
        expect.objectContaining({
          params: {
            ...expectedParams,
            project: mockProject,
            status: mockStatus,
            author_username: mockAuthor,
            assignee_username: mockAssignee,
            labels: [mockLabel],
            search: mockSearchTerm,
          },
        }),
      );
    });

    it('renders issuable-list component with correct props', () => {
      const issuableList = findIssuableList();

      expect(issuableList.props('initialFilterValue')).toEqual([
        { type: TOKEN_TYPE_LABEL, value: { data: mockLabel } },
        { type: FILTERED_SEARCH_TERM, value: { data: mockSearchTerm } },
      ]);
      expect(issuableList.props('urlParams').project).toBe(mockProject);
      expect(issuableList.props('urlParams').status).toBe(mockStatus);
      expect(issuableList.props('urlParams').author_username).toBe(mockAuthor);
      expect(issuableList.props('urlParams').assignee_username).toBe(mockAssignee);
      expect(issuableList.props('urlParams')['labels[]']).toEqual([mockLabel]);
      expect(issuableList.props('urlParams').search).toBe(mockSearchTerm);
    });

    describe('issuable-list events', () => {
      it.each`
        desc             | input                                 | expected
        ${'with label'}  | ${[createLabelFilterEvent('label2')]} | ${{ labels: ['label2'] }}
        ${'with search'} | ${[createSearchFilterEvent('foo')]}   | ${{ search: 'foo' }}
      `(
        '$desc, filter event sets "filterParams" value and calls fetchIssues',
        async ({ input, expected }) => {
          const issuableList = findIssuableList();

          issuableList.vm.$emit('filter', input);
          await waitForPromises();

          expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
            params: {
              ...expectedParams,
              project: mockProject,
              status: mockStatus,
              author_username: mockAuthor,
              assignee_username: mockAssignee,
              ...expected,
            },
          });
        },
      );
    });
  });

  describe('when request succeeds', () => {
    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

      createComponent();
      await waitForPromises();
    });

    it('renders issuable-list component with correct props', () => {
      const issuableList = findIssuableList();
      expect(issuableList.exists()).toBe(true);
      expect(issuableList.props()).toMatchSnapshot();
    });

    describe('issuable-list reference section', () => {
      it('renders issuable-list component with correct reference', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

        createComponent({ mountFn: mount });
        await waitForPromises();

        expect(wrapper.find('.issuable-info').text()).toContain(
          resolvedValue.data[0].references.relative,
        );
      });

      it('renders issuable-list component with id when references is not present', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue({
          ...resolvedValue,
          data: [mockJiraIssueNoReference],
        });

        createComponent({ mountFn: mount });
        await waitForPromises();

        // Since Jira transformer transforms references.relative into id, we can only test
        // whether it exists.
        expect(wrapper.find('.issuable-info').exists()).toBe(false);
      });
    });

    describe('issuable-list events', () => {
      it('"click-tab" event executes GET request correctly', async () => {
        const issuableList = findIssuableList();

        issuableList.vm.$emit('click-tab', 'closed');
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            ...expectedParams,
            state: 'closed',
          },
        });
        expect(issuableList.props('currentTab')).toBe('closed');
      });

      it('"page-change" event executes GET request correctly', async () => {
        const mockPage = 2;
        const issuableList = findIssuableList();
        jest.spyOn(axios, 'get').mockResolvedValue({
          ...resolvedValue,
          headers: { 'x-page': mockPage, 'x-total': mockExternalIssues.length },
        });

        issuableList.vm.$emit('page-change', mockPage);
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            ...expectedParams,
            page: mockPage,
          },
        });

        await nextTick();
        expect(issuableList.props()).toMatchObject({
          currentPage: mockPage,
          previousPage: mockPage - 1,
          nextPage: mockPage + 1,
        });
      });

      it('"sort" event executes GET request correctly', async () => {
        const mockSortBy = 'updated_asc';
        const issuableList = findIssuableList();

        issuableList.vm.$emit('sort', mockSortBy);
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            ...expectedParams,
            sort: 'updated_asc',
          },
        });
        expect(issuableList.props('initialSortBy')).toBe(mockSortBy);
      });

      it.each`
        desc                        | input                                                                           | expected
        ${'with label and search'}  | ${[createLabelFilterEvent(mockLabel), createSearchFilterEvent(mockSearchTerm)]} | ${{ labels: [mockLabel], search: mockSearchTerm }}
        ${'with multiple lables'}   | ${[createLabelFilterEvent('label1'), createLabelFilterEvent('label2')]}         | ${{ labels: ['label1', 'label2'], search: undefined }}
        ${'with multiple searches'} | ${[createSearchFilterEvent('foo bar'), createSearchFilterEvent('lorem')]}       | ${{ labels: undefined, search: 'foo bar lorem' }}
      `(
        '$desc, filter event sets "filterParams" value and calls fetchIssues',
        async ({ input, expected }) => {
          const issuableList = findIssuableList();

          issuableList.vm.$emit('filter', input);
          await waitForPromises();

          expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
            params: {
              ...expectedParams,
              ...expected,
            },
          });
        },
      );
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
    });

    describe('when request fails', () => {
      it.each`
        APIErrors                                         | expectedRenderedErrorText
        ${['API error']}                                  | ${'API error'}
        ${['API <a href="gitlab.com">error</a>']}         | ${'API error'}
        ${['API <script src="hax0r.xyz">error</script>']} | ${'API'}
        ${undefined}                                      | ${i18n.errorFetchingIssues}
      `(
        'displays error alert with "$expectedRenderedErrorText" when API responds with "$APIErrors"',
        async ({ APIErrors, expectedRenderedErrorText }) => {
          jest.spyOn(axios, 'get');
          mock
            .onGet(mockProvide.issuesFetchPath)
            .replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR, { errors: APIErrors });

          createComponent();
          await waitForPromises();

          expectErrorHandling(expectedRenderedErrorText);
          expect(findAlertMessage().html()).toMatchSnapshot();
        },
      );
    });

    describe('when GraphQL network error is encountered', () => {
      it('displays error alert with default error message', async () => {
        createComponent({
          apolloProvider: createMockApolloProvider({
            Query: {
              externalIssues: jest.fn().mockRejectedValue(new Error('GraphQL networkError')),
            },
          }),
        });
        await waitForPromises();

        expectErrorHandling(i18n.errorFetchingIssues);
      });
    });
  });

  describe('pagination', () => {
    it.each`
      scenario                 | issues                | shouldShowPaginationControls
      ${'returns no issues'}   | ${[]}                 | ${false}
      ${`returns some issues`} | ${mockExternalIssues} | ${true}
    `(
      'sets `showPaginationControls` prop to $shouldShowPaginationControls when request $scenario',
      async ({ issues, shouldShowPaginationControls }) => {
        jest.spyOn(axios, 'get');
        mock.onGet(mockProvide.issuesFetchPath).replyOnce(HTTP_STATUS_OK, issues, {
          'x-page': 1,
          'x-total': issues.length,
        });

        createComponent();
        await waitForPromises();

        expect(findIssuableList().props('showPaginationControls')).toBe(
          shouldShowPaginationControls,
        );
      },
    );
  });
});
