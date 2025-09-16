import { GlAlert, GlLoadingIcon, GlTable, GlKeysetPagination, GlToast } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { statusesInfo } from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ComplianceViolationsReportV2, {
  VIOLATION_PAGE_SIZE,
} from 'ee/compliance_dashboard/components/violations_report/report_v2.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import ComplianceFrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import groupComplianceViolationsQuery from 'ee/compliance_violations/graphql/compliance_violations.query.graphql';
import updateProjectComplianceViolation from 'ee/compliance_violations/graphql/mutations/update_project_compliance_violation.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/graphql_shared/utils', () => ({
  getIdFromGraphQLId: jest.fn(),
}));

describe('ComplianceViolationsReportV2 component', () => {
  let wrapper;

  const groupPath = 'group-path';

  const mockViolationsResponse = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceViolation/1',
              createdAt: '2025-06-08T10:00:00Z',
              status: 'detected',
              project: {
                id: 'gid://gitlab/Project/1',
                name: 'Frontend Project',
                fullPath: 'foo/bar',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/1',
                name: 'scanner_sast_running',
                complianceRequirement: {
                  id: 'gid://gitlab/ComplianceRequirement/1',
                  name: 'Code Review Requirement',
                  framework: {
                    id: 'gid://gitlab/ComplianceFramework/1',
                    name: 'SOX Framework',
                    color: '#1f75cb',
                    default: false,
                    description: 'Sarbanes-Oxley compliance framework',
                  },
                },
              },
              auditEvent: {
                id: 'gid://gitlab/AuditEvent/1',
                createdAt: '2025-06-08T09:30:00Z',
                details:
                  '{:event_name=\u003e"request_to_compliance_external_control_failed", :author_name=\u003e"Administrator", :author_class=\u003e"Gitlab::Audit::UnauthenticatedAuthor", :target_id=\u003e30, :target_type=\u003e"ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl", :target_details=\u003e"External control", :custom_message=\u003e"Request to compliance requirement external failed.", :ip_address=\u003enil, :entity_path=\u003e"p-compliance-group-1748445340/subgroup_1748445340/project-83"}',
                eventName: 'merge_request_approval_operation',
                entityPath: 'foo/bar',
                entityType: 'Project',
                targetDetails: 'Merge request #123',
                targetType: 'MergeRequest',
                author: {
                  id: 'gid://gitlab/User/1',
                  name: 'John Doe',
                  username: 'johndoe',
                },
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'cursor1',
            endCursor: 'cursor1',
          },
        },
      },
    },
  };

  const mockViolationsResponseWithPagination = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        name: 'Test Group',
        projectComplianceViolations: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceViolation/1',
              createdAt: '2025-06-08T10:00:00Z',
              status: 'detected',
              linkedAuditEventId: 'audit_event_1',
              project: {
                id: 'gid://gitlab/Project/1',
                name: 'Frontend Project',
                fullPath: 'foo/bar',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/1',
                name: 'minimum_approvals_required_1',
                complianceRequirement: {
                  id: 'gid://gitlab/ComplianceRequirement/1',
                  name: 'Code Review Requirement',
                  framework: {
                    id: 'gid://gitlab/ComplianceFramework/1',
                    name: 'SOX Framework',
                    color: '#1f75cb',
                    default: false,
                    description: 'Sarbanes-Oxley compliance framework',
                  },
                },
              },
              auditEvent: null,
            },
            {
              id: 'gid://gitlab/ComplianceViolation/2',
              createdAt: '2025-06-09T10:00:00Z',
              status: 'resolved',
              linkedAuditEventId: 'audit_event_2',
              project: {
                id: 'gid://gitlab/Project/2',
                name: 'Backend Project',
                fullPath: 'foo/baz',
              },
              complianceControl: {
                id: 'gid://gitlab/ComplianceControl/2',
                name: 'scanner_sast_running',
                complianceRequirement: {
                  id: 'gid://gitlab/ComplianceRequirement/2',
                  name: 'Approval Requirement',
                  framework: {
                    id: 'gid://gitlab/ComplianceFramework/2',
                    name: 'GDPR Framework',
                    color: '#d73a49',
                    default: true,
                    description: 'General Data Protection Regulation framework',
                  },
                },
              },
              auditEvent: null,
            },
          ],
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: 'cursor1',
            endCursor: 'cursor2',
          },
        },
      },
    },
  };

  const mockGraphQlSuccess = jest.fn().mockResolvedValue(mockViolationsResponse);
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockGraphQlError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const mockUpdateMutationSuccess = jest.fn().mockResolvedValue({
    data: {
      updateProjectComplianceViolation: {
        clientMutationId: 'test-id',
        errors: [],
        complianceViolation: {
          id: 'gid://gitlab/ComplianceViolation/1',
          status: 'RESOLVED',
          createdAt: '2025-06-08T10:00:00Z',
          complianceControl: {
            name: 'SOX - Code Review Required',
            complianceRequirement: {
              name: 'basic code regulation',
              framework: {
                id: 'gid://gitlab/ComplianceManagement::Framework/3',
                color: '#cd5b45',
                default: false,
                name: 'SOC 2',
                description: 'SOC 2 description',
              },
            },
          },
          project: {
            id: 'gid://gitlab/Project/1',
            nameWithNamespace: 'GitLab.org / GitLab Test',
            fullPath: 'gitlab-org/gitlab-test',
            webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
          },
        },
      },
    },
  });

  const mockUpdateMutationError = jest.fn().mockRejectedValue(new Error('Mutation error'));

  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findViolationsTable = () => wrapper.findComponent(GlTable);
  const findTableLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findFrameworkBadge = () => wrapper.findComponent(ComplianceFrameworkBadge);

  const tableRows = () => wrapper.findAll('tbody tr');

  const createMockApolloProvider = (
    resolverMock = mockGraphQlLoading,
    mutationMock = mockUpdateMutationSuccess,
  ) => {
    return createMockApollo([
      [groupComplianceViolationsQuery, resolverMock],
      [updateProjectComplianceViolation, mutationMock],
    ]);
  };

  const createComponent = ({
    mountFn = shallowMount,
    props = {},
    resolverMock = mockGraphQlLoading,
    mutationMock = mockUpdateMutationSuccess,
  } = {}) => {
    return extendedWrapper(
      mountFn(ComplianceViolationsReportV2, {
        apolloProvider: createMockApolloProvider(resolverMock, mutationMock),
        propsData: {
          groupPath,
          ...props,
        },
        stubs: {
          GlTable: false,
          ComplianceFrameworkBadge: false,
        },
      }),
    );
  };

  describe('default behavior', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('does not render an error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('renders the violations table', () => {
      expect(findViolationsTable().exists()).toBe(true);
    });
  });

  describe('when initializing', () => {
    beforeEach(() => {
      wrapper = createComponent({ mountFn: mount, resolverMock: mockGraphQlLoading });
    });

    it('renders the table loading icon', () => {
      expect(findViolationsTable().exists()).toBe(true);
      expect(findTableLoadingIcon().exists()).toBe(true);
    });

    it('fetches the list of compliance violations', () => {
      expect(mockGraphQlLoading).toHaveBeenCalledTimes(1);
      expect(mockGraphQlLoading).toHaveBeenCalledWith({
        fullPath: groupPath,
        first: VIOLATION_PAGE_SIZE,
        after: null,
        before: null,
      });
    });
  });

  describe('when the query fails', () => {
    beforeEach(async () => {
      wrapper = createComponent({ resolverMock: mockGraphQlError });
      await waitForPromises();
    });

    it('renders the error message', () => {
      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Unable to load the compliance violations report. Refresh the page and try again.',
      );
    });
  });

  describe('when there are violations', () => {
    beforeEach(async () => {
      wrapper = createComponent({ mountFn: mount, resolverMock: mockGraphQlSuccess });
      await waitForPromises();
    });

    it('does not render the table loading icon', () => {
      expect(findTableLoadingIcon().exists()).toBe(false);
    });

    it('renders violation data correctly', () => {
      const firstRow = tableRows().at(0);

      expect(tableRows()).toHaveLength(1);
      expect(firstRow.text()).toContain('Frontend Project');
      expect(firstRow.text()).toContain('SAST configuration');
      expect(firstRow.text()).toContain('Request to compliance requirement external failed.');
      expect(firstRow.text()).toContain('By John Doe');
    });

    it('renders status dropdown', () => {
      const statusDropdown = findStatusDropdown();

      expect(statusDropdown.exists()).toBe(true);
      expect(statusDropdown.props('disabled')).toBe(false);
      expect(statusDropdown.props('value')).toBe('detected');
      expect(statusDropdown.vm.selectedOption.text).toBe('Detected');
    });

    it('displays framework badge text in the compliance control column', () => {
      const frameworkBadge = findFrameworkBadge();
      const firstRow = tableRows().at(0);

      expect(frameworkBadge.exists()).toBe(true);
      expect(firstRow.text()).toContain('SOX Framework');
    });
  });

  describe('when there are no violations', () => {
    beforeEach(async () => {
      const emptyResponse = {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            name: 'Test Group',
            projectComplianceViolations: {
              nodes: [],
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: null,
                endCursor: null,
              },
            },
          },
        },
      };
      const mockResolver = jest.fn().mockResolvedValue(emptyResponse);
      wrapper = createComponent({ mountFn: mount, resolverMock: mockResolver });
      await waitForPromises();
    });

    it('renders the empty table message', () => {
      expect(findViolationsTable().text()).toContain('No violations found');
    });
  });

  describe('status change functionality', () => {
    beforeEach(async () => {
      wrapper = createComponent({
        mountFn: mount,
        resolverMock: mockGraphQlSuccess,
        mutationMock: mockUpdateMutationSuccess,
      });
      await waitForPromises();
    });

    it('calls mutation when status is changed', async () => {
      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mockUpdateMutationSuccess).toHaveBeenCalledWith({
        input: {
          id: 'gid://gitlab/ComplianceViolation/1',
          status: 'RESOLVED',
        },
      });
    });

    it('sets loading state during status update', async () => {
      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await nextTick();

      expect(statusDropdown.props('loading')).toBe(true);

      await waitForPromises();

      expect(statusDropdown.props('loading')).toBe(false);
    });

    it('shows success toast when mutation succeeds', async () => {
      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mockToast.show).toHaveBeenCalledWith('Violation status updated successfully.', {
        variant: 'success',
      });
    });

    it('shows error toast when mutation fails', async () => {
      wrapper = createComponent({
        mountFn: mount,
        resolverMock: mockGraphQlSuccess,
        mutationMock: mockUpdateMutationError,
      });
      await waitForPromises();

      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mockToast.show).toHaveBeenCalledWith(
        'Failed to update violation status. Please try again.',
        { variant: 'danger' },
      );
    });

    it('shows error toast when mutation returns errors', async () => {
      const mockMutationWithErrors = jest.fn().mockResolvedValue({
        data: {
          updateProjectComplianceViolation: {
            clientMutationId: 'test-id',
            errors: ['Validation failed'],
            complianceViolation: null,
          },
        },
      });

      wrapper = createComponent({
        mountFn: mount,
        resolverMock: mockGraphQlSuccess,
        mutationMock: mockMutationWithErrors,
      });
      await waitForPromises();

      const mockToast = { show: jest.fn() };
      wrapper.vm.$toast = mockToast;

      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mockToast.show).toHaveBeenCalledWith(
        'Failed to update violation status. Please try again.',
        { variant: 'danger' },
      );
    });

    it('resets loading state even when mutation fails', async () => {
      wrapper = createComponent({
        mountFn: mount,
        resolverMock: mockGraphQlSuccess,
        mutationMock: mockUpdateMutationError,
      });
      await waitForPromises();

      const statusDropdown = findStatusDropdown();
      statusDropdown.vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(wrapper.vm.isStatusUpdating).toBe(false);
    });
  });

  describe('pagination', () => {
    const paginationTestCases = {
      initial: {
        hasNextPage: true,
        hasPreviousPage: false,
        startCursor: 'cursor1',
        endCursor: 'cursor2',
      },
      afterNext: {
        expectedCursor: { after: 'cursor2', before: null },
      },
      afterPrevious: {
        expectedCursor: { before: 'cursor1', after: null },
      },
    };

    const expectPaginationProps = (expectedProps) => {
      const pagination = findPagination();
      Object.entries(expectedProps).forEach(([prop, value]) => {
        expect(pagination.props(prop)).toBe(value);
      });
    };

    const expectCursorState = (expectedCursor) => {
      Object.entries(expectedCursor).forEach(([key, value]) => {
        expect(wrapper.vm.cursor[key]).toBe(value);
      });
    };

    const triggerPaginationEvent = async (event) => {
      const pagination = findPagination();
      pagination.vm.$emit(event);
      await nextTick();
    };

    beforeEach(async () => {
      const mockResolver = jest.fn().mockResolvedValue(mockViolationsResponseWithPagination);
      wrapper = createComponent({ mountFn: mount, resolverMock: mockResolver });
      await waitForPromises();
    });

    it('renders pagination component with correct initial state', () => {
      expect(findPagination().exists()).toBe(true);
      expectPaginationProps(paginationTestCases.initial);
    });

    describe('navigation', () => {
      it('handles next page navigation correctly', async () => {
        await triggerPaginationEvent('next');
        expectCursorState(paginationTestCases.afterNext.expectedCursor);
      });

      it('handles previous page navigation correctly', async () => {
        await triggerPaginationEvent('prev');
        expectCursorState(paginationTestCases.afterPrevious.expectedCursor);
      });
    });
  });

  describe('getViolationDetailsPath', () => {
    beforeEach(() => {
      wrapper = createComponent();
      // Reset mock and set default behavior
      getIdFromGraphQLId.mockReset();
      getIdFromGraphQLId.mockImplementation((id) => {
        const match = id.match(/\/(\d+)$/);
        return match ? match[1] : null;
      });
    });

    it('returns correct path for valid violation with fullPath', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/project/-/security/compliance_violations/123');
    });

    it('returns correct path for valid violation with path_with_namespace', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/456',
        project: {
          path_with_namespace: 'group/another-project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/another-project/-/security/compliance_violations/456');
    });

    it('prefers fullPath over path_with_namespace when both exist', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/789',
        project: {
          fullPath: 'group/preferred-project',
          path_with_namespace: 'group/fallback-project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('/group/preferred-project/-/security/compliance_violations/789');
    });

    it('returns # when violation is null or undefined', () => {
      expect(wrapper.vm.getViolationDetailsPath(null)).toBe('#');
      expect(wrapper.vm.getViolationDetailsPath(undefined)).toBe('#');
    });

    it('returns # when violation.id is missing', () => {
      const violation = {
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when violation.project is missing', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when both fullPath and path_with_namespace are missing', () => {
      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {},
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when getIdFromGraphQLId throws an error', () => {
      getIdFromGraphQLId.mockImplementation(() => {
        throw new Error('Invalid GraphQL ID');
      });

      const violation = {
        id: 'invalid-graphql-id',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });

    it('returns # when getIdFromGraphQLId returns null or empty', () => {
      getIdFromGraphQLId.mockReturnValue(null);

      const violation = {
        id: 'gid://gitlab/ComplianceViolation/123',
        project: {
          fullPath: 'group/project',
        },
      };

      const result = wrapper.vm.getViolationDetailsPath(violation);
      expect(result).toBe('#');
    });
  });

  describe('getProjectPath', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('returns correct path for project with fullPath', () => {
      const project = {
        fullPath: 'group/project',
      };

      const result = wrapper.vm.getProjectPath(project);
      expect(result).toBe('/group/project');
    });

    it('returns correct path for project with path_with_namespace', () => {
      const project = {
        path_with_namespace: 'group/another-project',
      };

      const result = wrapper.vm.getProjectPath(project);
      expect(result).toBe('/group/another-project');
    });

    it('prefers fullPath over path_with_namespace when both exist', () => {
      const project = {
        fullPath: 'group/preferred-project',
        path_with_namespace: 'group/fallback-project',
      };

      const result = wrapper.vm.getProjectPath(project);
      expect(result).toBe('/group/preferred-project');
    });

    it('returns # when project is null or undefined', () => {
      expect(wrapper.vm.getProjectPath(null)).toBe('#');
      expect(wrapper.vm.getProjectPath(undefined)).toBe('#');
    });

    it('returns # when both fullPath and path_with_namespace are missing', () => {
      const project = {};

      const result = wrapper.vm.getProjectPath(project);
      expect(result).toBe('#');
    });
  });

  describe('getComplianceControlTitle', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('returns linkTitle from statusesInfo when control name matches', () => {
      const control = {
        name: 'scanner_sast_running',
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('SAST configuration');
    });

    it('returns linkTitle for known control names', () => {
      const control = {
        name: 'minimum_approvals_required_1',
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('Merge request approvals');
    });

    it('returns original name when control name not found in statusesInfo', () => {
      const control = {
        name: 'unknown_control_name',
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('unknown_control_name');
    });

    it('returns empty string when control is null or undefined', () => {
      expect(wrapper.vm.getComplianceControlTitle(null)).toBe('');
      expect(wrapper.vm.getComplianceControlTitle(undefined)).toBe('');
    });

    it('returns empty string when control.name is missing', () => {
      const control = {};

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('');
    });

    it('handles edge cases in statusesInfo structure', () => {
      const control = {
        name: 'default_branch_protected',
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('Protected branches');
    });

    it('handles statusInfo with null/undefined fixes', () => {
      const control = { name: 'test_control_null_fixes' };

      statusesInfo.test_control_null_fixes = {
        description: 'Test control',
        fixes: null,
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('test_control_null_fixes');
    });

    it('handles statusInfo with empty fixes array', () => {
      const control = { name: 'test_control_empty_fixes' };

      statusesInfo.test_control_empty_fixes = {
        description: 'Test control',
        fixes: [],
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('test_control_empty_fixes');
    });

    it('handles statusInfo with fixes[0] but no linkTitle', () => {
      const control = { name: 'test_control_no_link_title' };

      statusesInfo.test_control_no_link_title = {
        description: 'Test control',
        fixes: [
          {
            title: 'Fix title',
            description: 'Fix description',
          },
        ],
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('test_control_no_link_title');
    });

    it('handles statusInfo with fixes[0].linkTitle as null', () => {
      const control = { name: 'test_control_null_link_title' };

      statusesInfo.test_control_null_link_title = {
        description: 'Test control',
        fixes: [
          {
            title: 'Fix title',
            description: 'Fix description',
            linkTitle: null,
          },
        ],
      };

      const result = wrapper.vm.getComplianceControlTitle(control);
      expect(result).toBe('test_control_null_link_title');
    });
  });

  describe('getAuditEventTitle', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('returns with custom message when available', () => {
      const auditEvent = {
        eventName: 'some_event',
        targetType: 'control',
        targetDetails: 'MergeRequest',
        details: '{target_details=\u003e"Control", :custom_message=\u003e"Thing happened"}',
      };

      const result = wrapper.vm.getAuditEventTitle(auditEvent);
      expect(result).toBe('MergeRequest : Thing happened');
    });

    it('returns with event name when custom message not available', () => {
      const auditEvent = {
        eventName: 'some_event',
        targetType: 'control',
        targetDetails: 'MergeRequest',
        details: '{target_details=\u003e"Control", :entity_path=\u003e"/group1/project1"}',
      };

      const result = wrapper.vm.getAuditEventTitle(auditEvent);
      expect(result).toBe('MergeRequest : some_event');
    });

    it('returns generic audit event when no specific details are available', () => {
      const auditEvent = {
        details: {},
      };

      const result = wrapper.vm.getAuditEventTitle(auditEvent);
      expect(result).toBe('Generic Audit event');
    });

    it('returns empty string when audit event is null', () => {
      const result = wrapper.vm.getAuditEventTitle(null);
      expect(result).toBe('');
    });
  });

  describe('getAuditEventAuthor', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('returns author name from author object when available', () => {
      const auditEvent = {
        author: { name: 'Jane Smith', username: 'foobar' },
      };

      const result = wrapper.vm.getAuditEventAuthor(auditEvent);
      expect(result).toBe('By Jane Smith');
    });

    it('returns author username from author object when available', () => {
      const auditEvent = {
        author: { name: null, username: 'foobar' },
      };

      const result = wrapper.vm.getAuditEventAuthor(auditEvent);
      expect(result).toBe('By foobar');
    });

    it('returns unknown author when no author information is available', () => {
      const auditEvent = {};

      const result = wrapper.vm.getAuditEventAuthor(auditEvent);
      expect(result).toBe('Unknown author');
    });

    it('returns empty string when audit event is null', () => {
      const result = wrapper.vm.getAuditEventAuthor(null);
      expect(result).toBe('');
    });
  });

  describe('when violation has no audit event', () => {
    beforeEach(() => {
      const responseWithoutAuditEvent = {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            name: 'Test Group',
            projectComplianceViolations: {
              nodes: [
                {
                  id: 'gid://gitlab/ComplianceViolation/1',
                  createdAt: '2025-06-08T10:00:00Z',
                  status: 'detected',
                  project: {
                    id: 'gid://gitlab/Project/1',
                    name: 'Frontend Project',
                    fullPath: 'foo/bar',
                  },
                  complianceControl: {
                    id: 'gid://gitlab/ComplianceControl/1',
                    name: 'default_branch_protected',
                    complianceRequirement: {
                      id: 'gid://gitlab/ComplianceRequirement/1',
                      name: 'Code Review Requirement',
                      framework: {
                        id: 'gid://gitlab/ComplianceFramework/1',
                        name: 'SOX Framework',
                        color: '#1f75cb',
                        default: false,
                        description: 'Sarbanes-Oxley compliance framework',
                      },
                    },
                  },
                  auditEvent: null,
                },
              ],
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: 'cursor1',
                endCursor: 'cursor1',
              },
            },
          },
        },
      };

      const mockResolver = jest.fn().mockResolvedValue(responseWithoutAuditEvent);
      wrapper = createComponent({ mountFn: mount, resolverMock: mockResolver });
    });

    it('renders no audit event message', async () => {
      await waitForPromises();
      expect(tableRows()).toHaveLength(1);

      const firstRow = tableRows().at(0);
      expect(firstRow.text()).toContain('No audit event available');
    });
  });
});
