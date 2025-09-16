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
  projectVulnerabilityManagementPolicies,
  groupVulnerabilityManagementPolicies,
  mockLinkedSppItemsResponse,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { mockScanExecutionPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  mockPipelineExecutionPoliciesResponse,
  mockPipelineExecutionSchedulePoliciesResponse,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import { mockVulnerabilityManagementPoliciesResponse } from 'ee_jest/security_orchestration/mocks/mock_vulnerability_management_policy_data';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import projectPipelineExecutionSchedulePoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_schedule_policies.query.graphql';
import groupPipelineExecutionSchedulePoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_schedule_policies.query.graphql';
import projectVulnerabilityManagementPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_vulnerability_management_policies.query.graphql';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from './mocks';

Vue.use(VueApollo);

const projectScanExecutionPoliciesSpy = projectScanExecutionPolicies(
  mockScanExecutionPoliciesResponse,
);
const groupScanExecutionPoliciesSpy = groupScanExecutionPolicies(mockScanExecutionPoliciesResponse);
const projectScanResultPoliciesSpy = projectScanResultPolicies(mockScanResultPoliciesResponse);
const groupScanResultPoliciesSpy = groupScanResultPolicies(mockScanResultPoliciesResponse);
const projectPipelineExecutionPoliciesSpy = projectPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);
const groupPipelineExecutionPoliciesSpy = groupPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);
const projectPipelineExecutionSchedulePoliciesSpy = projectPipelineResultPolicies(
  mockPipelineExecutionSchedulePoliciesResponse,
);
const groupPipelineExecutionSchedulePoliciesSpy = groupPipelineResultPolicies(
  mockPipelineExecutionSchedulePoliciesResponse,
);
const projectVulnerabilityManagementPoliciesSpy = projectVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);
const groupVulnerabilityManagementPoliciesSpy = groupVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);
const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();

const defaultRequestHandlers = {
  projectScanExecutionPolicies: projectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: groupScanExecutionPoliciesSpy,
  projectScanResultPolicies: projectScanResultPoliciesSpy,
  groupScanResultPolicies: groupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: projectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: groupPipelineExecutionPoliciesSpy,
  projectPipelineExecutionSchedulePolicies: projectPipelineExecutionSchedulePoliciesSpy,
  groupPipelineExecutionSchedulePolicies: groupPipelineExecutionSchedulePoliciesSpy,
  projectVulnerabilityManagementPolicies: projectVulnerabilityManagementPoliciesSpy,
  groupVulnerabilityManagementPolicies: groupVulnerabilityManagementPoliciesSpy,
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
};

describe('Policies List', () => {
  let wrapper;
  let requestHandlers;

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

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
        [
          projectPipelineExecutionSchedulePoliciesQuery,
          requestHandlers.projectPipelineExecutionSchedulePolicies,
        ],
        [
          groupPipelineExecutionSchedulePoliciesQuery,
          requestHandlers.groupPipelineExecutionSchedulePolicies,
        ],
        [
          projectVulnerabilityManagementPoliciesQuery,
          requestHandlers.projectVulnerabilityManagementPolicies,
        ],
        [
          groupVulnerabilityManagementPoliciesQuery,
          requestHandlers.groupVulnerabilityManagementPolicies,
        ],
        [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
      ]),
    });
  };

  const findEmptyListState = () => wrapper.findByTestId('empty-list-state');

  describe('project level', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the page correctly', () => {
      expect(findPoliciesHeader().exists()).toBe(true);
      expect(findPoliciesList().exists()).toBe(true);
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.groupVulnerabilityManagementPolicies).not.toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.projectVulnerabilityManagementPolicies).toHaveBeenCalled();
    });
  });

  describe('group level', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });
    });

    it('fetches correct policies', () => {
      expect(requestHandlers.groupScanResultPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupScanExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupPipelineExecutionPolicies).toHaveBeenCalled();
      expect(requestHandlers.groupVulnerabilityManagementPolicies).toHaveBeenCalled();

      expect(requestHandlers.projectScanResultPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectScanExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectPipelineExecutionPolicies).not.toHaveBeenCalled();
      expect(requestHandlers.projectVulnerabilityManagementPolicies).not.toHaveBeenCalled();
    });
  });

  describe('network errors', () => {
    it('shows the empty list state', async () => {
      const errorHandlers = Object.keys(defaultRequestHandlers).reduce((acc, curr) => {
        acc[curr] = jest.fn().mockRejectedValue();
        return acc;
      }, {});
      createWrapper({ handlers: errorHandlers });
      await waitForPromises();
      expect(findEmptyListState().exists()).toBe(true);
    });
  });
});
