import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import {
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_SEARCH_WITHIN,
  TOKEN_TYPE_WEIGHT,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import getServiceDeskIssuesQuery from 'ee_else_ce/issues/service_desk/queries/get_service_desk_issues.query.graphql';
import getServiceDeskIssuesCountsQuery from 'ee_else_ce/issues/service_desk/queries/get_service_desk_issues_counts.query.graphql';
import ServiceDeskListApp from 'ee/issues/service_desk/components/service_desk_list_app.vue';
import ServiceDeskListAppBase from '~/issues/service_desk/components/service_desk_list_app.vue';
import {
  getServiceDeskIssuesQueryResponse,
  getServiceDeskIssuesCountsQueryResponse,
} from 'jest/issues/service_desk/mock_data';

describe('EE ServiceDeskListApp', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultProvide = {
    releasesPath: 'releases/path',
    autocompleteAwardEmojisPath: 'autocomplete/award/emojis/path',
    hasBlockedIssuesFeature: false,
    hasIterationsFeature: true,
    hasIssueWeightsFeature: true,
    hasIssuableHealthStatusFeature: true,
    groupPath: 'group/path',
    emptyStateSvgPath: 'empty-state.svg',
    serviceDeskCalloutSvgPath: 'callout.svg',
    serviceDeskSettingsPath: 'settings/path',
    serviceDeskHelpPath: 'help/path',
    isServiceDeskEnabled: true,
    isProject: true,
    isSignedIn: true,
    fullPath: 'path/to/project',
    signInPath: 'sign/in/path',
    hasAnyIssues: true,
    isServiceDeskSupported: true,
    canAdminIssues: true,
    canEditProjectSettings: true,
    serviceDeskEmailAddress: 'service@email.com',
    initialSort: '',
    isIssueRepositioningDisabled: true,
  };

  const defaultQueryResponse = cloneDeep(getServiceDeskIssuesQueryResponse);
  defaultQueryResponse.data.project.issues.nodes[0].healthStatus = null;
  defaultQueryResponse.data.project.issues.nodes[0].weight = 5;

  const mockServiceDeskIssuesQueryResponse = jest.fn().mockResolvedValue(defaultQueryResponse);
  const mockServiceDeskIssuesCountsQueryResponse = jest
    .fn()
    .mockResolvedValue(getServiceDeskIssuesCountsQueryResponse);

  const findIssuableList = () => wrapper.findComponent(IssuableList);

  const createComponent = ({
    provide = {},
    serviceDeskIssuesQueryResponse = mockServiceDeskIssuesQueryResponse,
    serviceDeskIssuesCountsQueryResponse = mockServiceDeskIssuesCountsQueryResponse,
  } = {}) => {
    const requestHandlers = [
      [getServiceDeskIssuesQuery, serviceDeskIssuesQueryResponse],
      [getServiceDeskIssuesCountsQuery, serviceDeskIssuesCountsQueryResponse],
    ];

    return shallowMount(ServiceDeskListApp, {
      apolloProvider: createMockApollo(
        requestHandlers,
        {},
        {
          typePolicies: {
            Query: {
              fields: {
                project: {
                  merge: true,
                },
              },
            },
          },
        },
      ),
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        ServiceDeskListApp: ServiceDeskListAppBase,
      },
    });
  };

  describe('Tokens', () => {
    const mockCurrentUser = {
      id: 1,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'avatar/url',
    };

    describe.each`
      feature         | property                    | tokenName      | type
      ${'iterations'} | ${'hasIterationsFeature'}   | ${'Iteration'} | ${TOKEN_TYPE_ITERATION}
      ${'epics'}      | ${'groupPath'}              | ${'Epic'}      | ${TOKEN_TYPE_EPIC}
      ${'weights'}    | ${'hasIssueWeightsFeature'} | ${'Weight'}    | ${TOKEN_TYPE_WEIGHT}
    `('when $feature are not available', ({ property, tokenName, type }) => {
      beforeEach(() => {
        wrapper = createComponent({ provide: { [property]: '' } });
        return waitForPromises();
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

        wrapper = createComponent();
        return waitForPromises();
      });

      it('renders all tokens alphabetically', () => {
        const preloadedUsers = [
          { ...mockCurrentUser, id: convertToGraphQLId(TYPENAME_USER, mockCurrentUser.id) },
        ];

        expect(findIssuableList().props('searchTokens')).toMatchObject([
          { type: TOKEN_TYPE_ASSIGNEE, preloadedUsers },
          { type: TOKEN_TYPE_CONFIDENTIAL },
          { type: TOKEN_TYPE_EPIC },
          { type: TOKEN_TYPE_HEALTH },
          { type: TOKEN_TYPE_ITERATION },
          { type: TOKEN_TYPE_LABEL },
          { type: TOKEN_TYPE_MILESTONE },
          { type: TOKEN_TYPE_MY_REACTION },
          { type: TOKEN_TYPE_RELEASE },
          { type: TOKEN_TYPE_SEARCH_WITHIN },
          { type: TOKEN_TYPE_WEIGHT },
        ]);
      });
    });
  });
});
