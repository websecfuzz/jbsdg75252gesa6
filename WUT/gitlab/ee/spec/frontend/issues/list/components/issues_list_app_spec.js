import { mount } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import getIssuesQuery from 'ee_else_ce/issues/list/queries/get_issues.query.graphql';
import getIssuesCountsQuery from 'ee_else_ce/issues/list/queries/get_issues_counts.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import { getIssuesCountsQueryResponse, getIssuesQueryResponse } from 'jest/issues/list/mock_data';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import IssuesListAppCE from '~/issues/list/components/issues_list_app.vue';
import { CREATED_DESC } from '~/issues/list/constants';
import { CUSTOM_FIELDS_TYPE_MULTI_SELECT } from '~/work_items/constants';
import {
  OPERATORS_IS,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_CONTACT,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_ORGANIZATION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_TYPE,
  TOKEN_TYPE_SEARCH_WITHIN,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_CREATED,
  TOKEN_TYPE_CLOSED,
  TOKEN_TYPE_CUSTOM_FIELD,
  TOKEN_TYPE_SUBSCRIBED,
  TOKEN_TYPE_STATUS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import BlockingIssuesCount from 'ee/issues/components/blocking_issues_count.vue';
import IssuesListApp from 'ee/issues/list/components/issues_list_app.vue';
import NewIssueDropdown from 'ee/issues/list/components/new_issue_dropdown.vue';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import searchEpicsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/search_epics.query.graphql';
import ChildEpicIssueIndicator from 'ee/issuable/child_epic_issue_indicator/components/child_epic_issue_indicator.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import {
  mockGroupEpicsQueryResponse,
  mockNamespaceCustomFieldsResponse,
} from 'ee_jest/vue_shared/components/filtered_search_bar/mock_data';

describe('EE IssuesListApp component', () => {
  let wrapper;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const defaultProvide = {
    autocompleteAwardEmojisPath: 'autocomplete/award/emojis/path',
    calendarPath: 'calendar/path',
    canBulkUpdate: false,
    canCreateIssue: false,
    canCreateProjects: false,
    canReadCrmContact: false,
    canReadCrmOrganization: false,
    exportCsvPath: 'export/csv/path',
    fullPath: 'path/to/project',
    groupPath: 'group/path',
    hasAnyIssues: true,
    hasAnyProjects: true,
    hasBlockedIssuesFeature: true,
    hasCustomFieldsFeature: true,
    hasEpicsFeature: true,
    hasIssueDateFilterFeature: true,
    hasIssuableHealthStatusFeature: true,
    hasIssueWeightsFeature: true,
    hasIterationsFeature: true,
    hasOkrsFeature: true,
    hasQualityManagementFeature: true,
    hasScopedLabelsFeature: true,
    initialEmail: 'email@example.com',
    initialSort: CREATED_DESC,
    isIssueRepositioningDisabled: false,
    isProject: true,
    isPublicVisibilityRestricted: false,
    isSignedIn: true,
    newIssuePath: 'new/issue/path',
    newProjectPath: 'new/project/path',
    releasesPath: 'releases/path',
    rssPath: 'rss/path',
    showNewIssueLink: true,
    signInPath: 'sign/in/path',
    groupId: '',
    isGroup: false,
    commentTemplatePaths: [],
    hasStatusFeature: true,
  };

  const defaultQueryResponse = cloneDeep(getIssuesQueryResponse);
  defaultQueryResponse.data.project.issues.nodes[0].blockingCount = 1;
  defaultQueryResponse.data.project.issues.nodes[0].healthStatus = null;
  defaultQueryResponse.data.project.issues.nodes[0].weight = 5;
  defaultQueryResponse.data.project.issues.nodes[0].epic = {
    id: 'gid://gitlab/Epic/1',
  };
  defaultQueryResponse.data.project.issues.nodes[0].status = {
    color: '#DD2B0E',
    iconName: 'status-cancelled',
    id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/4',
    name: "Won't do",
    description: null,
    position: 0,
    __typename: 'WorkItemStatus',
  };

  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findNewIssueDropdown = () => wrapper.findComponent(NewIssueDropdown);
  const findChildEpicIssueIndicator = () => wrapper.findComponent(ChildEpicIssueIndicator);
  const findStatusBadge = () => wrapper.findComponent(WorkItemStatusBadge);
  const findIssuesListAppCE = () => wrapper.findComponent(IssuesListAppCE);

  const mountComponent = ({
    noStatus = false,
    provide = {},
    issuesListCreateModal = false,
    okrsMvc = false,
    workItemStatusFeatureFlag = true,
    issuesQueryResponse = jest.fn().mockResolvedValue(defaultQueryResponse),
    issuesCountsQueryResponse = jest.fn().mockResolvedValue(getIssuesCountsQueryResponse),
    customFieldsQueryHandler = jest.fn().mockResolvedValue(mockNamespaceCustomFieldsResponse),
  } = {}) => {
    if (noStatus) {
      defaultQueryResponse.data.project.issues.nodes[0].status = null;
    }
    return mount(IssuesListApp, {
      apolloProvider: createMockApollo([
        [getIssuesQuery, issuesQueryResponse],
        [getIssuesCountsQuery, issuesCountsQueryResponse],
        [searchEpicsQuery, jest.fn().mockResolvedValue(mockGroupEpicsQueryResponse)],
        [namespaceCustomFieldsQuery, customFieldsQueryHandler],
      ]),
      provide: {
        glFeatures: {
          issuesListCreateModal,
          okrsMvc,
          workItemStatusFeatureFlag,
        },
        ...defaultProvide,
        ...provide,
      },
      router: new VueRouter({ mode: 'history' }),
      stubs: {
        CreateWorkItemModal: true,
        NewIssueDropdown: true,
      },
    });
  };

  describe('template', () => {
    beforeEach(async () => {
      wrapper = mountComponent();
      jest.runOnlyPendingTimers();
      await waitForPromises();
    });

    it('shows blocking issues count', () => {
      expect(wrapper.findComponent(BlockingIssuesCount).props('blockingIssuesCount')).toBe(
        defaultQueryResponse.data.project.issues.nodes[0].blockingCount,
      );
    });
  });

  describe('tokens', () => {
    const mockCurrentUser = {
      id: 1,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'avatar/url',
    };

    describe.each`
      feature              | property                    | tokenName                      | type
      ${'iterations'}      | ${'hasIterationsFeature'}   | ${'Iteration'}                 | ${TOKEN_TYPE_ITERATION}
      ${'epics'}           | ${'groupPath'}              | ${'Epic'}                      | ${TOKEN_TYPE_EPIC}
      ${'weights'}         | ${'hasIssueWeightsFeature'} | ${'Weight'}                    | ${TOKEN_TYPE_WEIGHT}
      ${'custom fields'}   | ${'hasCustomFieldsFeature'} | ${'CustomField'}               | ${TOKEN_TYPE_CUSTOM_FIELD}
      ${'custom statuses'} | ${'hasStatusFeature'}       | ${'WorkItemCustomStatusToken'} | ${TOKEN_TYPE_STATUS}
    `('when $feature are not available', ({ property, tokenName, type }) => {
      beforeEach(() => {
        wrapper = mountComponent({ provide: { [property]: '' } });
      });

      it(`does not render ${tokenName} token`, () => {
        expect(findIssuableList().props('searchTokens')).not.toMatchObject([{ type }]);
      });
    });

    describe('when all tokens are available', () => {
      beforeEach(() => {
        gon.current_user_id = mockCurrentUser.id;
        gon.current_user_fullname = mockCurrentUser.name;
        gon.current_username = mockCurrentUser.username;
        gon.current_user_avatar_url = mockCurrentUser.avatar_url;

        wrapper = mountComponent({
          provide: {
            canReadCrmContact: true,
            canReadCrmOrganization: true,
            groupPath: 'group/path',
            hasIssueWeightsFeature: true,
            hasIterationsFeature: true,
            isSignedIn: true,
          },
        });
      });

      it('renders all tokens alphabetically', () => {
        const preloadedUsers = [
          { ...mockCurrentUser, id: convertToGraphQLId(TYPENAME_USER, mockCurrentUser.id) },
        ];

        expect(findIssuableList().props('searchTokens')).toMatchObject([
          { type: TOKEN_TYPE_ASSIGNEE, preloadedUsers },
          { type: TOKEN_TYPE_AUTHOR, preloadedUsers },
          { type: TOKEN_TYPE_CLOSED },
          { type: TOKEN_TYPE_CONFIDENTIAL },
          { type: TOKEN_TYPE_CONTACT },
          { type: TOKEN_TYPE_CREATED },
          { type: TOKEN_TYPE_EPIC },
          { type: TOKEN_TYPE_HEALTH },
          { type: TOKEN_TYPE_ITERATION },
          { type: TOKEN_TYPE_LABEL },
          { type: TOKEN_TYPE_MILESTONE },
          { type: TOKEN_TYPE_MY_REACTION },
          { type: TOKEN_TYPE_ORGANIZATION },
          { type: TOKEN_TYPE_RELEASE },
          { type: TOKEN_TYPE_SEARCH_WITHIN },
          { type: TOKEN_TYPE_STATUS },
          { type: TOKEN_TYPE_SUBSCRIBED },
          { type: TOKEN_TYPE_TYPE },
          { type: TOKEN_TYPE_WEIGHT },
        ]);
      });
    });
  });

  describe('custom status token', () => {
    it('does not render `WorkItemStatusToken` token when the `work_item_status_feature_flag` is off', () => {
      wrapper = mountComponent({
        provide: {
          workItemStatusFeatureFlag: false,
        },
      });

      expect(findIssuableList().props('searchTokens')).not.toContain([{ type: TOKEN_TYPE_STATUS }]);
    });
  });

  describe('custom fields', () => {
    const mockCustomFields = mockNamespaceCustomFieldsResponse.data.namespace.customFields.nodes;
    const allowedFields = mockCustomFields.filter((field) =>
      ['SINGLE_SELECT', 'MULTI_SELECT'].includes(field.fieldType),
    );
    const customFieldsQueryHandler = jest.fn().mockResolvedValue(mockNamespaceCustomFieldsResponse);

    beforeEach(async () => {
      wrapper = mountComponent({
        customFieldsQueryHandler,
      });
      await waitForPromises();
    });

    it('fetches custom fields when component is mounted', () => {
      expect(customFieldsQueryHandler).toHaveBeenCalledWith({
        fullPath: 'path/to/project',
        active: true,
      });
    });

    it('passes custom field tokens to IssuesListApp and unique field is based on field type', () => {
      const expectedTokens = allowedFields.map((field) => ({
        type: `${TOKEN_TYPE_CUSTOM_FIELD}[${field.id.split('/').pop()}]`,
        title: field.name,
        icon: 'multiple-choice',
        field,
        fullPath: 'path/to/project',
        token: expect.any(Function),
        operators: OPERATORS_IS,
        unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
      }));

      expect(findIssuesListAppCE().props('eeSearchTokens')).toHaveLength(8);
      expect(findIssuesListAppCE().props('eeSearchTokens')[4]).toMatchObject(expectedTokens[0]);
      expect(findIssuesListAppCE().props('eeSearchTokens')[5]).toMatchObject(expectedTokens[1]);
      expect(findIssuesListAppCE().props('eeSearchTokens')[6]).toMatchObject(expectedTokens[2]); // Task type only
    });
  });

  describe('NewIssueDropdown component', () => {
    it('renders when okrs is enabled', async () => {
      wrapper = mountComponent({ provide: { hasOkrsFeature: true }, okrsMvc: true });
      await waitForPromises();

      expect(findNewIssueDropdown().exists()).toBe(true);
    });

    it('does not render when okrs is disabled', async () => {
      wrapper = mountComponent({ provide: { hasOkrsFeature: false }, okrsMvc: false });
      await waitForPromises();

      expect(findNewIssueDropdown().exists()).toBe(false);
    });

    it('does not render when group', async () => {
      wrapper = mountComponent({
        provide: { hasOkrsFeature: true, isProject: false },
        okrsMvc: true,
      });
      await waitForPromises();

      expect(findNewIssueDropdown().exists()).toBe(false);
    });

    it('does not render when issuesListCreateModal is enabled', async () => {
      wrapper = mountComponent({
        issuesListCreateModal: true,
        provide: { hasOkrsFeature: true },
        okrsMvc: true,
      });
      await waitForPromises();

      expect(findNewIssueDropdown().exists()).toBe(false);
    });
  });

  describe('ChildEpicIssueIndicator component', () => {
    it('renders ChildEpicIssueIndicator when there is filtered epic id', async () => {
      setWindowLocation('?&epic_id=1');

      wrapper = await mountComponent();

      await waitForPromises();

      expect(findChildEpicIssueIndicator().exists()).toBe(true);
    });

    it('does not render ChildEpicIssueIndicator when the filtered epic id is not present', async () => {
      setWindowLocation('');

      wrapper = await mountComponent();

      await waitForPromises();

      expect(findChildEpicIssueIndicator().exists()).toBe(false);
    });
  });

  describe('WorkItemStatusBadge component', () => {
    it('renders `WorkItemStatusBadge` when there is custom status', async () => {
      wrapper = await mountComponent();

      await waitForPromises();

      expect(findStatusBadge().exists()).toBe(true);
    });

    it('does not render `WorkItemStatusBadge` when there is no custom status', async () => {
      wrapper = await mountComponent({ noStatus: true });

      await waitForPromises();

      expect(findStatusBadge().exists()).toBe(false);
    });
  });

  describe('when searched by epics', () => {
    it.each`
      context                   | location          | searchedByEpic
      ${'has epicId'}           | ${'?&epic_id=12'} | ${true}
      ${'does not have epicId'} | ${'?&state=open'} | ${false}
    `(
      'pass `searchedByEpic` as $searchedByEpic to the `IssuesListAppCE` in case URL $context',
      async ({ location, searchedByEpic }) => {
        setWindowLocation(location);
        wrapper = await mountComponent();

        expect(findIssuesListAppCE().props('searchedByEpic')).toEqual(searchedByEpic);
      },
    );

    it.each`
      context                   | params               | searchedByEpic
      ${'has epicId'}           | ${{ epicId: 12 }}    | ${true}
      ${'does not have epicId'} | ${{ state: 'open' }} | ${false}
    `(
      'pass `searchedByEpic` as $searchedByEpic to the `IssuesListAppCE` in case filter params $context',
      async ({ params, searchedByEpic }) => {
        wrapper = await mountComponent();

        await findIssuesListAppCE().vm.$emit('updateFilterParams', params);

        expect(findIssuesListAppCE().props('searchedByEpic')).toEqual(searchedByEpic);
      },
    );
  });
});
