import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  projectPipelineResultPolicies,
  groupPipelineResultPolicies,
  mockLinkedSppItemsResponse,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { mockScanExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import { mockPipelineExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import App from 'ee/security_orchestration/components/policies/app.vue';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import { DEFAULT_PROVIDE } from '../mocks';
import { groups as includingGroups, projects, generateMockResponse, openDrawer } from './utils';

Vue.use(VueApollo);

const emptyPolicyScope = {
  includingProjects: {
    nodes: projects,
    pageInfo: {},
  },
  excludingProjects: {
    nodes: projects,
    pageInfo: {},
  },
};

const mockPipelineExecutionPoliciesProjectResponse = generateMockResponse(
  0,
  mockPipelineExecutionPoliciesResponse,
  emptyPolicyScope,
);
const mockPipelineExecutionPoliciesGroupResponse = generateMockResponse(
  1,
  mockPipelineExecutionPoliciesResponse,
  emptyPolicyScope,
);

const mockScanExecutionPoliciesProjectResponse = generateMockResponse(
  0,
  mockScanExecutionPoliciesResponse,
  emptyPolicyScope,
);
const mockScanExecutionPoliciesGroupResponse = generateMockResponse(
  1,
  mockScanExecutionPoliciesResponse,
  emptyPolicyScope,
);

const mockScanResultPoliciesProjectResponse = generateMockResponse(
  0,
  mockScanResultPoliciesResponse,
  emptyPolicyScope,
);
const mockScanResultPoliciesGroupResponse = generateMockResponse(
  1,
  mockScanResultPoliciesResponse,
  emptyPolicyScope,
);

/**
 * New mocks for policy scope including linked groups on project level
 * @type {jest.Mock<any, any, any>}
 */
const newProjectPipelineExecutionPoliciesSpy = projectPipelineResultPolicies([
  mockPipelineExecutionPoliciesProjectResponse,
  mockPipelineExecutionPoliciesGroupResponse,
]);

const newProjectScanExecutionPoliciesSpy = projectScanExecutionPolicies([
  mockScanExecutionPoliciesProjectResponse,
  mockScanExecutionPoliciesGroupResponse,
]);
const newProjectScanResultPoliciesSpy = projectScanResultPolicies([
  mockScanResultPoliciesProjectResponse,
  mockScanResultPoliciesGroupResponse,
]);

/**
 * New mocks for policy scope including linked groups on group level
 * @type {jest.Mock<any, any, any>}
 */
const newGroupPipelineExecutionPoliciesSpy = groupPipelineResultPolicies([
  mockPipelineExecutionPoliciesProjectResponse,
  mockPipelineExecutionPoliciesGroupResponse,
]);

const newGroupScanExecutionPoliciesSpy = groupScanExecutionPolicies([
  mockScanExecutionPoliciesProjectResponse,
  mockScanExecutionPoliciesGroupResponse,
]);
const newGroupScanResultPoliciesSpy = groupScanResultPolicies([
  mockScanResultPoliciesProjectResponse,
  mockScanResultPoliciesGroupResponse,
]);

const defaultRequestHandlers = {
  projectScanExecutionPolicies: newProjectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: newGroupScanExecutionPoliciesSpy,
  projectScanResultPolicies: newProjectScanResultPoliciesSpy,
  groupScanResultPolicies: newGroupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: newProjectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: newGroupPipelineExecutionPoliciesSpy,
  linkedSppItemsResponse: mockLinkedSppItemsResponse(),
};

describe('Policies List policy scope edge cases', () => {
  let wrapper;
  let requestHandlers;

  const createWrapper = ({ handlers = [], provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = mountExtended(App, {
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
        [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
        [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
        [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
        [projectPipelineExecutionPoliciesQuery, requestHandlers.projectPipelineExecutionPolicies],
        [groupPipelineExecutionPoliciesQuery, requestHandlers.groupPipelineExecutionPolicies],
        [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
      ]),
    });
  };

  const findTable = () => wrapper.findByTestId('policies-list');
  const findScopeInfoRow = () => wrapper.findComponent(ScopeInfoRow);
  const findAllListComponentScope = () => wrapper.findAllComponents(ListComponentScope);

  describe('project level', () => {
    describe('renders default text', () => {
      it.each`
        policyType              | policyScopeRowIndex | selectedRow
        ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}
      `(
        'scoped to itself when project is not SPP for $policyType',
        async ({ policyScopeRowIndex, selectedRow }) => {
          createWrapper();

          await waitForPromises();

          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe('This project');

          await openDrawer(findTable(), [selectedRow]);

          expect(findScopeInfoRow().text()).toContain('This policy is applied to current project.');
        },
      );

      it.each`
        policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
        ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'1 project: test'}
        ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'1 project: test'}
        ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'1 project: test'}
      `(
        'specific projects override exceptions projects on project level for SPP',
        async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
          createWrapper({
            handlers: {
              linkedSppItemsResponse: mockLinkedSppItemsResponse({
                groups: includingGroups,
                namespaces: includingGroups,
              }),
            },
          });

          await waitForPromises();

          expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

          await openDrawer(findTable(), [selectedRow]);

          expect(findScopeInfoRow().text()).toContain(expectedResult);
        },
      );
    });
  });

  describe('group level', () => {
    it.each`
      policyType              | policyScopeRowIndex | selectedRow                                     | expectedResult
      ${'Pipeline execution'} | ${4}                | ${mockPipelineExecutionPoliciesProjectResponse} | ${'1 project: test'}
      ${'Scan execution'}     | ${1}                | ${mockScanExecutionPoliciesProjectResponse}     | ${'1 project: test'}
      ${'Scan Result'}        | ${2}                | ${mockScanResultPoliciesProjectResponse}        | ${'1 project: test'}
    `(
      'specific projects override exceptions projects on group level',
      async ({ policyScopeRowIndex, selectedRow, expectedResult }) => {
        createWrapper({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });

        await waitForPromises();

        expect(findAllListComponentScope().at(policyScopeRowIndex).text()).toBe(expectedResult);

        await openDrawer(findTable(), [selectedRow]);

        expect(findScopeInfoRow().text()).toContain(expectedResult);
      },
    );
  });
});
