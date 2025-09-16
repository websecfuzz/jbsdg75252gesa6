import { GlAlert, GlLoadingIcon, GlToast } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';
import AuditEvent from 'ee/compliance_violations/components/audit_event.vue';
import ViolationSection from 'ee/compliance_violations/components/violation_section.vue';
import FixSuggestionSection from 'ee/compliance_violations/components/fix_suggestion_section.vue';
import { ComplianceViolationStatusDropdown } from 'ee/vue_shared/compliance';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';
import updateProjectComplianceViolation from 'ee/compliance_violations/graphql/mutations/update_project_compliance_violation.mutation.graphql';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;
  let mockApollo;
  let queryHandler;
  let mutationHandler;

  const violationId = '123';
  const complianceCenterPath = 'mock/compliance-center';

  const mockComplianceViolationData = {
    data: {
      projectComplianceViolation: {
        id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
        status: 'IN_REVIEW',
        createdAt: '2025-06-16T02:20:41Z',
        complianceControl: {
          id: 'gid://gitlab/ComplianceManagement::ComplianceControl/1',
          name: 'Test Control',
          complianceRequirement: {
            id: 'gid://gitlab/ComplianceManagement::ComplianceRequirement/1',
            name: 'Test Requirement',
            framework: {
              id: 'gid://gitlab/ComplianceManagement::Framework/1',
              color: '#1f75cb',
              default: false,
              name: 'Test Framework',
              description: 'Test framework description',
            },
          },
        },
        project: {
          id: 'gid://gitlab/Project/2',
          nameWithNamespace: 'GitLab.org / GitLab Test',
          fullPath: '/gitlab/org/gitlab-test',
          webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
          __typename: 'Project',
        },
        auditEvent: {
          id: 'gid://gitlab/AuditEvents::ProjectAuditEvent/467',
          eventName: 'merge_request_merged',
          targetId: '2',
          details: '{}',
          ipAddress: '123.1.1.9',
          entityPath: 'gitlab-org/gitlab-test',
          entityId: '2',
          entityType: 'Project',
          author: {
            id: 'gid://gitlab/User/1',
            name: 'John Doe',
          },
          project: {
            id: 'gid://gitlab/Project/2',
            name: 'Test project',
            fullPath: 'gitlab-org/gitlab-test',
            webUrl: 'https://localhost:3000/gitlab/org/gitlab-test',
          },
          group: null,
          user: {
            id: 'gid://gitlab/User/1',
            name: 'John Doe',
          },
        },
        __typename: 'ComplianceManagement::Projects::ComplianceViolation',
      },
    },
  };

  const mockUpdateResponseData = {
    data: {
      updateProjectComplianceViolation: {
        clientMutationId: null,
        errors: [],
        complianceViolation: {
          status: 'RESOLVED',
          __typename: 'ComplianceManagement::Projects::ComplianceViolation',
        },
        __typename: 'UpdateProjectComplianceViolationPayload',
      },
    },
  };

  const mockGraphQlError = jest.fn().mockRejectedValue(new Error('GraphQL error'));

  const mockComplianceViolation = mockComplianceViolationData.data.projectComplianceViolation;

  const mockDataWithoutAuditEvent = {
    data: {
      projectComplianceViolation: {
        ...mockComplianceViolation,
        auditEvent: null,
      },
    },
  };

  const createComponent = ({
    props = {},
    mockQueryHandler = jest.fn().mockResolvedValue(mockComplianceViolationData),
    mockMutationHandler = jest.fn().mockResolvedValue(mockUpdateResponseData),
  } = {}) => {
    queryHandler = mockQueryHandler;
    mutationHandler = mockMutationHandler;

    mockApollo = createMockApollo([
      [complianceViolationQuery, queryHandler],
      [updateProjectComplianceViolation, mutationHandler],
    ]);

    wrapper = shallowMountExtended(ComplianceViolationDetailsApp, {
      apolloProvider: mockApollo,
      propsData: {
        violationId,
        complianceCenterPath,
        ...props,
      },
    });
  };

  const findLoadingStatus = () =>
    wrapper.findByTestId('compliance-violation-details-loading-status');
  const findStatusDropdown = () => wrapper.findComponent(ComplianceViolationStatusDropdown);
  const findViolationDetails = () => wrapper.findByTestId('compliance-violation-details');
  const findAuditEvent = () => wrapper.findComponent(AuditEvent);
  const findViolationSection = () => wrapper.findComponent(ViolationSection);
  const findFixSuggestionSection = () => wrapper.findComponent(FixSuggestionSection);
  const findErrorMessage = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('when the query fails', () => {
    beforeEach(async () => {
      createComponent({ mockQueryHandler: mockGraphQlError });
      await waitForPromises();
    });

    it('renders the error message', () => {
      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe(
        'Failed to load the compliance violation. Refresh the page and try again.',
      );
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      // Create a query handler that never resolves to keep the component in loading state
      const loadingQueryHandler = jest.fn().mockImplementation(() => new Promise(() => {}));
      createComponent({ mockQueryHandler: loadingQueryHandler });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findLoadingStatus().exists()).toBe(true);
    });

    it('does not show violation details', () => {
      expect(findViolationDetails().exists()).toBe(false);
    });
  });

  describe('when loaded with violation data', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not show loading icon', () => {
      expect(findLoadingStatus().exists()).toBe(false);
    });

    it('shows violation details', () => {
      expect(findViolationDetails().exists()).toBe(true);
    });

    it('displays the correct title', () => {
      const title = wrapper.findByTestId('compliance-violation-title');
      expect(title.text()).toBe(`Details of vio-${violationId}`);
    });

    it('renders the status dropdown with correct props', () => {
      const dropdown = findStatusDropdown();
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        value: 'in_review',
        loading: false,
      });
    });

    it('displays the project location with link', () => {
      const { project } = mockComplianceViolation;
      const projectLink = wrapper.findByTestId('compliance-violation-location-link');
      expect(projectLink.exists()).toBe(true);
      expect(projectLink.text()).toBe(project.nameWithNamespace);
      expect(projectLink.attributes('href')).toBe(project.webUrl);
    });

    it('renders the violation section', () => {
      const violationSectionComponent = findViolationSection();
      expect(violationSectionComponent.exists()).toBe(true);
      expect(violationSectionComponent.props('control')).toEqual(
        mockComplianceViolation.complianceControl,
      );
      expect(violationSectionComponent.props('complianceCenterPath')).toBe(complianceCenterPath);
    });

    it('renders the fix suggestion section', () => {
      const fixSuggestionSectionComponent = findFixSuggestionSection();
      expect(fixSuggestionSectionComponent.exists()).toBe(true);
      expect(fixSuggestionSectionComponent.props('controlId')).toBe(
        mockComplianceViolation.complianceControl.id,
      );
      expect(fixSuggestionSectionComponent.props('projectPath')).toBe(
        mockComplianceViolation.project.webUrl,
      );
    });

    describe('when violation has an audit event', () => {
      it('renders the audit event component with correct props', () => {
        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(true);
        expect(auditEventComponent.props('auditEvent')).toEqual(mockComplianceViolation.auditEvent);
      });
    });

    describe('when violation does not have an audit event', () => {
      it('does not render the audit event component', async () => {
        createComponent({
          mockQueryHandler: jest.fn().mockResolvedValue(mockDataWithoutAuditEvent),
        });
        await waitForPromises();

        const auditEventComponent = findAuditEvent();
        expect(auditEventComponent.exists()).toBe(false);
      });
    });
  });

  describe('status update', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('calls mutation when status is changed', async () => {
      findStatusDropdown().vm.$emit('change', 'resolved');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          id: `gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/${violationId}`,
          status: 'RESOLVED',
        },
      });
    });

    it('sets loading state during status update', async () => {
      const dropdown = findStatusDropdown();
      dropdown.vm.$emit('change', 'resolved');
      await nextTick();

      expect(dropdown.props('loading')).toBe(true);

      await waitForPromises();

      expect(dropdown.props('loading')).toBe(false);
    });

    describe('error handling', () => {
      beforeEach(async () => {
        createComponent({
          mockMutationHandler: jest.fn().mockRejectedValue(new Error('Mutation error')),
        });

        const mockToast = { show: jest.fn() };
        wrapper.vm.$toast = mockToast;

        await waitForPromises();
      });

      it('shows error toast when mutation fails', async () => {
        findStatusDropdown().vm.$emit('change', 'resolved');
        await waitForPromises();

        expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
          'Failed to update compliance violation status. Please try again later.',
          { variant: 'danger' },
        );
      });

      it('resets loading state even when mutation fails', async () => {
        const dropdown = findStatusDropdown();

        dropdown.vm.$emit('change', 'resolved');

        await nextTick();
        expect(dropdown.props('loading')).toBe(true);

        await waitForPromises();
        expect(dropdown.props('loading')).toBe(false);
      });
    });
  });
});
