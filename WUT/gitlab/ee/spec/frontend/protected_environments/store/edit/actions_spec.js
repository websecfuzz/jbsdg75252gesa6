import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import {
  fetchProtectedEnvironments,
  setPage,
  fetchAllMembers,
  fetchAllMembersForEnvironment,
  fetchMembers,
  deleteRule,
  setRule,
  saveRule,
  updateRule,
  updateEnvironment,
  unprotectEnvironment,
  updateApproverInheritance,
  updateRequiredApprovals,
} from 'ee/protected_environments/store/edit/actions';
import * as types from 'ee/protected_environments/store/edit/mutation_types';
import { state } from 'ee/protected_environments/store/edit/state';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import {
  DEPLOYER_RULE_KEY,
  RULE_KEYS,
  NON_INHERITED_GROUPS,
  INHERITED_GROUPS,
} from 'ee/protected_environments/constants';
import { MAINTAINER_ACCESS_LEVEL, DEVELOPER_ACCESS_LEVEL } from '../../constants';

describe('ee/protected_environments/store/edit/actions', () => {
  let mockedState;
  let mock;

  beforeEach(() => {
    mockedState = state({ entityId: '8', entityType: 'projects' });
    mock = new MockAdapter(axios);
    window.gon = { api_version: 'v4' };
  });

  afterEach(() => {
    mock.restore();
    mock.resetHistory();
  });

  describe('fetchProtectedEnvironments', () => {
    it('successfully calls the protected environments API and saves the result', () => {
      const environments = [{ name: 'staging' }];

      const pageInfo = {
        page: 1,
        nextPage: 2,
        previousPage: 1,
        perPage: 10,
        total: 50,
        totalPages: 5,
      };
      const headers = {
        'X-Next-Page': pageInfo.nextPage,
        'X-Page': pageInfo.page,
        'X-Per-Page': pageInfo.perPage,
        'X-Prev-Page': pageInfo.previousPage,
        'X-Total': pageInfo.total,
        'X-Total-Pages': pageInfo.totalPages,
      };

      mock.onGet().replyOnce(HTTP_STATUS_OK, environments, headers);
      return testAction(
        fetchProtectedEnvironments,
        undefined,
        mockedState,
        [
          { type: types.REQUEST_PROTECTED_ENVIRONMENTS },
          { type: types.RECEIVE_PROTECTED_ENVIRONMENTS_SUCCESS, payload: environments },
          { type: types.SET_PAGINATION, payload: pageInfo },
        ],
        [{ type: 'fetchAllMembers' }],
      );
    });

    it('saves the error on failure', () => {
      mock.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      return testAction(
        fetchProtectedEnvironments,
        undefined,
        mockedState,
        [
          { type: types.REQUEST_PROTECTED_ENVIRONMENTS },
          { type: types.RECEIVE_PROTECTED_ENVIRONMENTS_ERROR, payload: expect.any(Error) },
        ],
        [],
      );
    });
  });

  describe('setPage', () => {
    it('commits the page to the store', () => {
      const page = 2;

      return testAction(
        setPage,
        { page },
        mockedState,
        [{ type: types.SET_PAGE, payload: { page } }],
        [{ type: 'fetchProtectedEnvironments' }],
      );
    });
  });

  describe('fetchAllMembers', () => {
    it('successfully fetches members for every deploy access rule in every environment', () => {
      const deployLevelsForStaging = [{ group_id: 1 }, { user_id: 1 }];
      const deployLevelsForProduction = [{ group_id: 2 }, { user_id: 2 }];
      const environments = [
        { name: 'staging', deploy_access_levels: deployLevelsForStaging },
        { name: 'production', deploy_access_levels: deployLevelsForProduction },
      ];

      mockedState.protectedEnvironments = environments;

      return testAction(
        fetchAllMembers,
        undefined,
        mockedState,
        [{ type: types.REQUEST_MEMBERS }, { type: types.RECEIVE_MEMBERS_FINISH }],
        [...environments.map((env) => ({ type: 'fetchAllMembersForEnvironment', payload: env }))],
      );
    });
  });

  describe('fetchAllMembersForEnvironment', () => {
    it('successfully fetches all members for a given environment', () => {
      const deployLevels = [{ group_id: 1 }, { user_id: 1 }];
      const approvalRules = [{ group_id: 2 }, { user_id: 2 }];
      const environment = {
        name: 'staging',
        deploy_access_levels: deployLevels,
        approval_rules: approvalRules,
      };

      return testAction(
        fetchAllMembersForEnvironment,
        environment,
        mockedState,
        [],
        RULE_KEYS.flatMap((type) =>
          environment[type].map((rule) => ({ type: 'fetchMembers', payload: { type, rule } })),
        ),
      );
    });
  });

  describe('fetchMembers', () => {
    it.each`
      type                                | rule                                                                                                     | url                               | response                                                                | entityType
      ${'group with integer inheritance'} | ${{ group_id: 1, user_id: null, access_level: null, group_inheritance_type: 1 }}                         | ${'/api/v4/groups/1/members/all'} | ${[{ name: 'root' }]}                                                   | ${'groups'}
      ${'group without inheritance'}      | ${{ group_id: 1, user_id: null, access_level: null, group_inheritance_type: 0 }}                         | ${'/api/v4/groups/1/members'}     | ${[{ name: 'root' }]}                                                   | ${'groups'}
      ${'user'}                           | ${{ group_id: null, user_id: 1, access_level: null, group_inheritance_type: null }}                      | ${'/api/v4/users/1'}              | ${{ name: 'root' }}                                                     | ${'groups'}
      ${'access level'}                   | ${{ group_id: null, user_id: null, access_level: MAINTAINER_ACCESS_LEVEL, group_inheritance_type: '0' }} | ${'/api/v4/projects/8/members'}   | ${[{ name: 'root', access_level: MAINTAINER_ACCESS_LEVEL.toString() }]} | ${'projects'}
      ${'all project members'}            | ${{ group_id: null, user_id: null, access_level: MAINTAINER_ACCESS_LEVEL, group_inheritance_type: '0' }} | ${'/api/v4/projects/8/members'}   | ${[{ name: 'root', access_level: MAINTAINER_ACCESS_LEVEL.toString() }]} | ${'projects'}
      ${'all group members'}              | ${{ group_id: null, user_id: null, access_level: MAINTAINER_ACCESS_LEVEL, group_inheritance_type: '0' }} | ${'/api/v4/groups/8/members'}     | ${[{ name: 'root', access_level: MAINTAINER_ACCESS_LEVEL.toString() }]} | ${'groups'}
    `(
      'successfully fetches members for a given deploy access rule of type $type',
      ({ rule, url, response, entityType }) => {
        mock.onGet(url).replyOnce(HTTP_STATUS_OK, response);
        const currentState = { ...mockedState, entityType };

        return testAction(
          fetchMembers,
          { type: DEPLOYER_RULE_KEY, rule },
          currentState,
          [
            {
              type: types.RECEIVE_MEMBER_SUCCESS,
              payload: { rule, type: DEPLOYER_RULE_KEY, users: [].concat(response) },
            },
          ],
          [],
        );
      },
    );

    it('filters out users that do not meet the requested deploy access level for access level rules', () => {
      const rule = {
        group_id: null,
        user_id: null,
        access_level: MAINTAINER_ACCESS_LEVEL,
        group_inheritance_type: '0',
      };

      const url = '/api/v4/projects/8/members';
      const root = { name: 'root', access_level: MAINTAINER_ACCESS_LEVEL.toString() };
      const response = [root, { name: 'alice', access_level: DEVELOPER_ACCESS_LEVEL.toString() }];

      mock.onGet(url).replyOnce(HTTP_STATUS_OK, response);

      return testAction(
        fetchMembers,
        { type: DEPLOYER_RULE_KEY, rule },
        mockedState,
        [
          {
            type: types.RECEIVE_MEMBER_SUCCESS,
            payload: { rule, type: DEPLOYER_RULE_KEY, users: [root] },
          },
        ],
        [],
      );
    });

    it('saves the error on a failure', () => {
      mock.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      const rule = {
        group_id: null,
        user_id: null,
        access_level: MAINTAINER_ACCESS_LEVEL,
        group_inheritance_type: '0',
      };

      return testAction(
        fetchMembers,
        { type: DEPLOYER_RULE_KEY, rule },
        mockedState,
        [{ type: types.RECEIVE_MEMBERS_ERROR, payload: expect.any(Error) }],
        [],
      );
    });

    it('throws an error for an unknown entityType', () => {
      const rule = {
        group_id: null,
        user_id: null,
        access_level: MAINTAINER_ACCESS_LEVEL,
        group_inheritance_type: '0',
      };

      const stateWithUnknownEntityType = { ...mockedState, entityType: 'unknown' };

      expect(() => {
        fetchMembers({ state: stateWithUnknownEntityType }, { type: DEPLOYER_RULE_KEY, rule });
      }).toThrow('Unexpected entityType: unknown');
    });
  });

  describe('deleteRule', () => {
    let environment;

    beforeEach(() => {
      environment = { name: 'staging' };
    });

    it.each`
      type              | rule                                                                                                            | updatedRule
      ${'group'}        | ${{ id: 1, group_id: 1, user_id: null, access_level: null, group_inheritance_type: '1' }}                       | ${{ id: 1, group_id: 1, group_inheritance_type: '1', _destroy: true }}
      ${'user'}         | ${{ id: 1, group_id: null, user_id: 1, access_level: null, group_inheritance_type: null }}                      | ${{ id: 1, user_id: 1, _destroy: true }}
      ${'access level'} | ${{ id: 1, group_id: null, user_id: null, access_level: MAINTAINER_ACCESS_LEVEL, group_inheritance_type: '0' }} | ${{ id: 1, access_level: MAINTAINER_ACCESS_LEVEL, group_inheritance_type: '0', _destroy: true }}
    `('marks a rule for deletion of type $type', ({ rule, updatedRule }) => {
      return testAction(
        deleteRule,
        { environment, rule, ruleKey: DEPLOYER_RULE_KEY },
        mockedState,
        [],
        [
          {
            type: 'updateEnvironment',
            payload: { ...environment, [DEPLOYER_RULE_KEY]: [updatedRule] },
          },
        ],
      );
    });
  });

  describe('updateRule', () => {
    let environment;

    beforeEach(() => {
      environment = { name: 'staging' };
    });

    it('filters out all null attributes for rule updating', () => {
      const rule = {
        id: 1,
        group_id: 1,
        user_id: null,
        access_level: null,
        group_inheritance_type: '1',
      };
      const updatedRule = { id: 1, group_id: 1, group_inheritance_type: '1' };

      mockedState.editingRules = { [rule.id]: rule };

      return testAction(
        updateRule,
        { environment, rule, ruleKey: DEPLOYER_RULE_KEY },
        mockedState,
        [{ type: types.RECEIVE_RULE_UPDATED, payload: rule }],
        [
          {
            type: 'updateEnvironment',
            payload: { ...environment, [DEPLOYER_RULE_KEY]: [updatedRule] },
          },
        ],
      );
    });
  });

  describe('updateEnvironment', () => {
    let environment;
    const url = '/api/v4/projects/8/protected_environments/staging';

    beforeEach(() => {
      environment = { name: 'staging' };
    });

    it('sends the updated environment to the API successfully', () => {
      const updatedEnvironment = { name: 'production' };
      mock.onPut(url, environment).replyOnce(HTTP_STATUS_OK, updatedEnvironment);

      return testAction(
        updateEnvironment,
        environment,
        mockedState,
        [
          {
            type: types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT,
          },
          { type: types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_SUCCESS, payload: updatedEnvironment },
        ],
        [{ type: 'fetchAllMembersForEnvironment', payload: updatedEnvironment }],
      );
    });

    it('successfully retains the error', () => {
      mock.onPut(url, environment).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(
        updateEnvironment,
        environment,
        mockedState,
        [
          {
            type: types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT,
          },
          { type: types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_ERROR, payload: expect.any(Error) },
        ],
        [],
      );
    });
  });

  describe('setRule', () => {
    it('commits the new rule to the environment', () => {
      const environment = { name: 'staging' };
      const newRules = [{ group_id: 5 }];

      return testAction(setRule, { environment, newRules }, mockedState, [
        { type: types.SET_RULE, payload: { environment, rules: newRules } },
      ]);
    });
  });

  describe('saveRule', () => {
    it('sends only new rules to update the environment', () => {
      const environment = {
        name: 'staging',
        deploy_access_levels: [{ group_id: 5, user_id: null, access_level: null }],
      };
      mockedState.newDeployAccessLevelsForEnvironment[environment.name] = [
        { group_id: 5 },
        { user_id: 1 },
      ];

      return testAction(
        saveRule,
        { environment, ruleKey: DEPLOYER_RULE_KEY },
        mockedState,
        [],
        [
          {
            type: 'updateEnvironment',
            payload: {
              ...environment,
              deploy_access_levels: [{ user_id: 1 }],
            },
          },
        ],
      );
    });

    it('sends only environment name to update the environment', () => {
      const environment = {
        name: 'staging',
        required_approval_count: 2,
        deploy_access_levels: [{ group_id: 5, user_id: null, access_level: null }],
      };
      mockedState.newDeployAccessLevelsForEnvironment[environment.name] = [{ user_id: 1 }];

      return testAction(
        saveRule,
        { environment, ruleKey: DEPLOYER_RULE_KEY },
        mockedState,
        [],
        [
          {
            type: 'updateEnvironment',
            payload: {
              name: environment.name,
              deploy_access_levels: [{ user_id: 1 }],
            },
          },
        ],
      );
    });
  });
  describe('updateApproverInheritance', () => {
    let rule;
    beforeEach(() => {
      rule = { group_id: 5 };
    });

    it.each`
      value    | result
      ${false} | ${NON_INHERITED_GROUPS}
      ${true}  | ${INHERITED_GROUPS}
    `('sets group inheritance to $result when passed $value', ({ value, result }) => {
      return testAction({
        action: updateApproverInheritance,
        mockedState,
        payload: { rule, value },
        expectedMutations: [
          { type: types.EDIT_RULE, payload: { ...rule, group_inheritance_type: result } },
        ],
      });
    });
  });
  describe('updateRequiredApprovals', () => {
    const rule = {
      group_id: 5,
      required_approvals: '1',
    };

    it('sets approval rule required approvals', () => {
      return testAction({
        action: updateRequiredApprovals,
        mockedState,
        payload: { rule, value: '2' },
        expectedMutations: [
          { type: types.EDIT_RULE, payload: { ...rule, required_approvals: '2' } },
        ],
      });
    });
  });
  describe('unprotectEnvironment', () => {
    const url = '/api/v4/projects/8/protected_environments/staging';

    it('unprotects an environment', () => {
      const environment = {
        name: 'staging',
      };
      mock.onDelete(url, environment).replyOnce(HTTP_STATUS_OK);

      return testAction(
        unprotectEnvironment,
        environment,
        mockedState,
        [
          { type: types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT },
          { type: types.DELETE_PROTECTED_ENVIRONMENT_SUCCESS, payload: environment },
        ],
        [],
      );
    });

    it('saves the error on failure', () => {
      const environment = {
        name: 'staging',
      };
      mock.onDelete(url, environment).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(
        unprotectEnvironment,
        environment,
        mockedState,
        [
          { type: types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT },
          { type: types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_ERROR, payload: expect.any(Error) },
        ],
        [],
      );
    });

    it('redirects to previous page after deleting if current page is empty', () => {
      const environment = {
        name: 'staging',
      };

      mockedState.pageInfo = {
        page: 2,
        nextPage: null,
        previousPage: 1,
        perPage: 10,
        total: 11,
        totalPages: 2,
      };

      mock.onDelete(url, environment).replyOnce(HTTP_STATUS_OK);

      return testAction({
        action: unprotectEnvironment,
        payload: environment,
        state: mockedState,
        expectedMutations: [
          { type: types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT },
          { type: types.DELETE_PROTECTED_ENVIRONMENT_SUCCESS, payload: environment },
        ],
        expectedActions: [
          {
            type: 'setPage',
            payload: 1,
          },
        ],
      });
    });
  });
});
