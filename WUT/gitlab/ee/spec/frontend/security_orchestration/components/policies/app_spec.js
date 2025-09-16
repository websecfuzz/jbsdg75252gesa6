import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import {
  MAX_SCAN_EXECUTION_ACTION_COUNT,
  MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  DEPRECATED_CUSTOM_SCAN_PROPERTY,
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
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
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import * as urlUtils from '~/lib/utils/url_utility';
import {
  mockGroupPipelineExecutionPolicyCombinedList,
  mockGroupPipelineExecutionSchedulePolicyCombinedList,
  mockPipelineExecutionPoliciesResponse,
  mockPipelineExecutionSchedulePoliciesResponse,
  mockProjectPipelineExecutionPolicyCombinedList,
  mockProjectPipelineExecutionSchedulePolicyCombinedList,
} from '../../mocks/mock_pipeline_execution_policy_data';
import {
  mockProjectVulnerabilityManagementPolicyCombinedList,
  mockVulnerabilityManagementPoliciesResponse,
} from '../../mocks/mock_vulnerability_management_policy_data';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  projectPipelineResultPolicies,
  groupPipelineResultPolicies,
  projectPipelineExecutionSchedulePolicies,
  groupPipelineExecutionSchedulePolicies,
  projectVulnerabilityManagementPolicies,
  groupVulnerabilityManagementPolicies,
  mockLinkedSppItemsResponse,
  groupSecurityPolicies,
  projectSecurityPolicies,
  groupByType,
  defaultPageInfo,
} from '../../mocks/mock_apollo';
import {
  mockGroupScanExecutionPolicyCombinedList,
  mockProjectScanExecutionPolicy,
  mockProjectScanExecutionPolicyCombinedList,
  mockScanExecutionPoliciesResponse,
  mockScanExecutionPoliciesWithSameNamesDifferentSourcesResponse,
} from '../../mocks/mock_scan_execution_policy_data';
import {
  mockScanResultPoliciesResponse,
  mockProjectScanResultPolicy,
  mockGroupScanResultPolicyCombinedList,
  mockProjectScanResultPolicyCombinedList,
} from '../../mocks/mock_scan_result_policy_data';

jest.mock('~/alert');

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
const projectPipelineExecutionSchedulePoliciesSpy = projectPipelineExecutionSchedulePolicies(
  mockPipelineExecutionSchedulePoliciesResponse,
);
const groupPipelineExecutionSchedulePoliciesSpy = groupPipelineExecutionSchedulePolicies(
  mockPipelineExecutionSchedulePoliciesResponse,
);
const projectVulnerabilityManagementPoliciesSpy = projectVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);
const groupVulnerabilityManagementPoliciesSpy = groupVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);

const combinedGroupPolicyList = [
  mockProjectVulnerabilityManagementPolicyCombinedList,
  mockGroupPipelineExecutionPolicyCombinedList,
  mockGroupPipelineExecutionSchedulePolicyCombinedList,
  mockGroupScanResultPolicyCombinedList,
  mockGroupScanExecutionPolicyCombinedList,
];

const combinedProjectPolicyList = [
  mockProjectVulnerabilityManagementPolicyCombinedList,
  mockProjectPipelineExecutionPolicyCombinedList,
  mockProjectPipelineExecutionSchedulePolicyCombinedList,
  mockProjectScanResultPolicyCombinedList,
  mockProjectScanExecutionPolicyCombinedList,
];

const groupSecurityPoliciesSpy = groupSecurityPolicies(combinedGroupPolicyList);
const projectSecurityPoliciesSpy = projectSecurityPolicies(combinedProjectPolicyList);

const flattenedProjectSecurityPolicies = groupByType(combinedProjectPolicyList);

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
  groupSecurityPolicies: groupSecurityPoliciesSpy,
  projectSecurityPolicies: projectSecurityPoliciesSpy,
};

describe('App', () => {
  let wrapper;
  let requestHandlers;
  const namespacePath = 'path/to/project/or/group';

  const createWrapper = ({ assignedPolicyProject = null, handlers = {}, provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = shallowMountExtended(App, {
      provide: {
        assignedPolicyProject,
        enabledExperiments: ['pipeline_execution_schedule_policy'],
        glFeatures: {
          scheduledPipelineExecutionPolicies: true,
          securityPoliciesCombinedList: false,
        },
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        maxScanExecutionPolicyActions: MAX_SCAN_EXECUTION_ACTION_COUNT,
        maxScanExecutionPolicySchedules: MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT,
        ...provide,
      },
      apolloProvider: createMockApollo(
        [
          [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
          [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
          [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
          [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
          [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
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
          [groupSecurityPoliciesQuery, requestHandlers.groupSecurityPolicies],
          [projectSecurityPoliciesQuery, requestHandlers.projectSecurityPolicies],
        ],
        {},
        { typePolicies: { ScanExecutionPolicy: { keyFields: ['name', 'updatedAt'] } } },
      ),
    });
  };

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  describe('loading', () => {
    it('renders the policies list correctly', () => {
      createWrapper();
      expect(findPoliciesList().props('isLoadingPolicies')).toBe(true);
    });
  });

  describe('default', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the policies list correctly', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          shouldUpdatePolicyList: false,
          hasPolicyProject: false,
          selectedPolicySource: POLICY_SOURCE_OPTIONS.ALL.value,
          selectedPolicyType: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
        }),
      );
      expect(findPoliciesList().props('policiesByType')).toEqual({
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
          mockPipelineExecutionPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          mockPipelineExecutionSchedulePoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          mockVulnerabilityManagementPoliciesResponse,
      });
    });

    it('renders the policy header correctly', () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
    });

    it('fetches linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(1);
    });

    it('does not fetch combined policy list when ff is false', () => {
      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(0);
    });

    it('updates the policy list when a the security policy project is changed', async () => {
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
      findPoliciesHeader().vm.$emit('update-policy-list', {
        shouldUpdatePolicyList: true,
        hasPolicyProject: true,
      });
      await nextTick();
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(true);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });

    it.each`
      type                             | groupHandler                                | projectHandler
      ${'scan execution'}              | ${'groupScanExecutionPolicies'}             | ${'projectScanExecutionPolicies'}
      ${'scan result'}                 | ${'groupScanResultPolicies'}                | ${'projectScanResultPolicies'}
      ${'pipeline execution'}          | ${'groupPipelineExecutionPolicies'}         | ${'projectPipelineExecutionPolicies'}
      ${'pipeline execution schedule'} | ${'groupPipelineExecutionSchedulePolicies'} | ${'projectPipelineExecutionSchedulePolicies'}
      ${'vulnerability management'}    | ${'groupVulnerabilityManagementPolicies'}   | ${'projectVulnerabilityManagementPolicies'}
    `(
      'fetches project-level $type policies instead of group-level',
      ({ groupHandler, projectHandler }) => {
        expect(requestHandlers[groupHandler]).not.toHaveBeenCalled();
        expect(requestHandlers[projectHandler]).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        });
      },
    );
  });

  it('renders scan execution policies with different sources and same name', async () => {
    const projectScanExecutionPoliciesWitSameNameSpy = projectScanExecutionPolicies(
      mockScanExecutionPoliciesWithSameNamesDifferentSourcesResponse,
    );

    createWrapper({
      handlers: { projectScanExecutionPolicies: projectScanExecutionPoliciesWitSameNameSpy },
    });
    await waitForPromises();

    expect(findPoliciesList().props('policiesByType').SCAN_EXECUTION[0].source).toEqual({
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    });

    expect(findPoliciesList().props('policiesByType').SCAN_EXECUTION[1].source).toEqual({
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    });
  });

  it('renders correctly when a policy project is linked', async () => {
    createWrapper({ assignedPolicyProject: { id: '1' } });
    await nextTick();

    expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
  });

  describe('network errors', () => {
    beforeEach(async () => {
      const errorHandlers = Object.keys(defaultRequestHandlers).reduce((acc, curr) => {
        acc[curr] = jest.fn().mockRejectedValue();
        return acc;
      }, {});
      createWrapper({ handlers: errorHandlers });
      await waitForPromises();
    });

    it('shows an alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(6);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch policies',
      });
    });

    it('uses an empty array as the default value', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          linkedSppItems: [],
          policiesByType: {
            APPROVAL: [],
            PIPELINE_EXECUTION: [],
            PIPELINE_EXECUTION_SCHEDULE: [],
            SCAN_EXECUTION: [],
            VULNERABILITY_MANAGEMENT: [],
          },
        }),
      );
    });
  });

  describe('group-level policies', () => {
    beforeEach(async () => {
      createWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      await waitForPromises();
    });

    it('does not fetch linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(0);
    });

    it.each`
      type                          | groupHandler                              | projectHandler
      ${'scan execution'}           | ${'groupScanExecutionPolicies'}           | ${'projectScanExecutionPolicies'}
      ${'scan result'}              | ${'groupScanResultPolicies'}              | ${'projectScanResultPolicies'}
      ${'pipeline execution'}       | ${'groupPipelineExecutionPolicies'}       | ${'projectPipelineExecutionPolicies'}
      ${'vulnerability management'} | ${'groupVulnerabilityManagementPolicies'} | ${'projectVulnerabilityManagementPolicies'}
    `(
      'fetches group-level $type policies instead of project-level',
      ({ groupHandler, projectHandler }) => {
        expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
        expect(requestHandlers[groupHandler]).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        });
      },
    );
  });

  describe('invalid policies', () => {
    it('updates "hasInvalidPolicies" when there are deprecated properties in scan result policies that are not "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['test', 'test1'] },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are deprecated properties in scan result policies that are "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['scan_result_policy'] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: [] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });
  });

  describe('deprecated custom scan action policies', () => {
    it('updates "hasDeprecatedCustomScanPolicies" when there are deprecated properties in scan execution policies', async () => {
      createWrapper({
        handlers: {
          projectScanExecutionPolicies: projectScanExecutionPolicies([
            {
              ...mockProjectScanExecutionPolicy,
              deprecatedProperties: [DEPRECATED_CUSTOM_SCAN_PROPERTY],
            },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper({
        handlers: {
          projectScanExecutionPolicies: projectScanExecutionPolicies([
            { ...mockProjectScanExecutionPolicy, deprecatedProperties: [] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
    });
  });

  describe('pipeline execution schedule policy retrieval', () => {
    it.each([
      [[], false],
      [[], true],
      [['pipeline_execution_schedule_policy'], false],
    ])(
      'does not request the pipeline execution schedule policies when enabledExperiments: %s and glFeatures: %s',
      async (enabledExperiments, glFeatures) => {
        createWrapper({
          provide: {
            enabledExperiments,
            glFeatures: { scheduledPipelineExecutionPolicies: glFeatures },
          },
        });
        await waitForPromises();

        expect(requestHandlers.projectPipelineExecutionSchedulePolicies).not.toHaveBeenCalled();
      },
    );
  });

  describe('combined policy list', () => {
    const policiesByType = {
      [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
        flattenedProjectSecurityPolicies[POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter],
      [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]:
        flattenedProjectSecurityPolicies[POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter],
      [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
        flattenedProjectSecurityPolicies[
          POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter
        ],
      [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
        flattenedProjectSecurityPolicies[
          POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter
        ],
      [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
        flattenedProjectSecurityPolicies[
          POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement.urlParameter
        ],
    };

    it('loads combined list without scheduled policies', async () => {
      createWrapper({
        provide: {
          glFeatures: {
            scheduledPipelineExecutionPolicies: false,
            securityPoliciesCombinedList: true,
          },
        },
      });

      await waitForPromises();

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(1);
      expect(requestHandlers.projectPipelineExecutionSchedulePolicies).toHaveBeenCalledTimes(0);

      expect(findPoliciesList().props('policiesByType')).toEqual(policiesByType);
    });

    it('loads full combined policy list', async () => {
      createWrapper({
        provide: {
          enabledExperiments: ['pipeline_execution_schedule_policy'],
          glFeatures: {
            scheduledPipelineExecutionPolicies: true,
            securityPoliciesCombinedList: true,
          },
        },
      });
      await waitForPromises();

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(1);
      expect(requestHandlers.projectVulnerabilityManagementPolicies).toHaveBeenCalledTimes(0);
      expect(requestHandlers.projectScanResultPolicies).toHaveBeenCalledTimes(0);
      expect(requestHandlers.projectScanExecutionPolicies).toHaveBeenCalledTimes(0);
      expect(requestHandlers.projectPipelineExecutionPolicies).toHaveBeenCalledTimes(0);
      expect(requestHandlers.projectPipelineExecutionSchedulePolicies).toHaveBeenCalledTimes(0);

      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          shouldUpdatePolicyList: false,
          hasPolicyProject: false,
          selectedPolicySource: POLICY_SOURCE_OPTIONS.ALL.value,
          selectedPolicyType: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
        }),
      );

      expect(findPoliciesList().props('policiesByType')).toEqual({
        ...policiesByType,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION_SCHEDULE.value]:
          flattenedProjectSecurityPolicies[
            POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecutionSchedule.urlParameter
          ],
      });
    });
  });

  describe('filtering policies', () => {
    describe.each`
      emittedType                      | expectedType
      ${'APPROVAL'}                    | ${'APPROVAL_POLICY'}
      ${'SCAN_EXECUTION'}              | ${'SCAN_EXECUTION_POLICY'}
      ${'PIPELINE_EXECUTION'}          | ${'PIPELINE_EXECUTION_POLICY'}
      ${'PIPELINE_EXECUTION_SCHEDULE'} | ${'PIPELINE_EXECUTION_SCHEDULE_POLICY'}
      ${'VULNERABILITY_MANAGEMENT'}    | ${'VULNERABILITY_MANAGEMENT_POLICY'}
    `('filters policies by type', ({ emittedType, expectedType }) => {
      it('does not refresh policy list when feature flag is disabled', async () => {
        createWrapper();

        await waitForPromises();

        await findPoliciesList().vm.$emit('update-policy-type', emittedType);

        expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledTimes(0);
      });

      it('filters policies by type', async () => {
        createWrapper({
          provide: {
            glFeatures: {
              securityPoliciesCombinedList: true,
            },
          },
        });

        await waitForPromises();

        await findPoliciesList().vm.$emit('update-policy-type', emittedType);

        expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          after: '',
          before: '',
          first: 50,
          type: expectedType,
        });
      });

      it('sets correct selected from query type', async () => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(emittedType.toLowerCase());

        createWrapper({
          provide: {
            glFeatures: {
              securityPoliciesCombinedList: true,
            },
          },
        });

        await waitForPromises();

        expect(requestHandlers.projectSecurityPolicies).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
          after: '',
          before: '',
          first: 50,
          type: expectedType,
        });
      });
    });
  });

  describe('pagination', () => {
    it('fetches next page when policy list is changed to a next page', async () => {
      createWrapper({
        provide: {
          glFeatures: {
            securityPoliciesCombinedList: true,
          },
        },
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies(combinedProjectPolicyList, {
            ...defaultPageInfo,
            endCursor: 'next',
          }),
        },
      });
      await waitForPromises();

      await findPoliciesList().vm.$emit('next-page');

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        after: 'next',
        before: '',
        first: 50,
      });
    });

    it('fetches previous page when policy list is changed to a previous page', async () => {
      createWrapper({
        provide: {
          glFeatures: {
            securityPoliciesCombinedList: true,
          },
        },
        handlers: {
          projectSecurityPolicies: projectSecurityPolicies(combinedProjectPolicyList, {
            ...defaultPageInfo,
            startCursor: 'previous',
          }),
        },
      });
      await waitForPromises();

      await findPoliciesList().vm.$emit('prev-page');

      expect(requestHandlers.projectSecurityPolicies).toHaveBeenNthCalledWith(2, {
        fullPath: namespacePath,
        relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        after: '',
        before: 'previous',
        first: null,
        last: 50,
      });
    });
  });
});
