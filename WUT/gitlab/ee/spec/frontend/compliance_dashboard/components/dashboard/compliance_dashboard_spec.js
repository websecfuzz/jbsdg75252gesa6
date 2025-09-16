import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { getSystemColorScheme } from '~/lib/utils/css_utils';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ComplianceDashboard from 'ee/compliance_dashboard/components/dashboard/compliance_dashboard.vue';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import FailedRequirements from 'ee/compliance_dashboard/components/dashboard/failed_requirements.vue';
import FailedControls from 'ee/compliance_dashboard/components/dashboard/failed_controls.vue';
import FrameworksNeedsAttention from 'ee/compliance_dashboard/components/dashboard/frameworks_needs_attention.vue';
import DashboardLayout from '~/vue_shared/components/customizable_dashboard/dashboard_layout.vue';
import frameworkCoverageQuery from 'ee/compliance_dashboard/components/dashboard/graphql/framework_coverage.query.graphql';
import failedRequirementsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_requirements.query.graphql';
import failedControlsQuery from 'ee/compliance_dashboard/components/dashboard/graphql/failed_controls.query.graphql';
import frameworksNeedsAttentionQuery from 'ee/compliance_dashboard/components/dashboard/graphql/frameworks_needs_attention.query.graphql';
import { GL_LIGHT } from '~/constants';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/css_utils');

getSystemColorScheme.mockReturnValue(GL_LIGHT);

const generateFrameworkCoverageQueryMockResponse = (count = 5) => ({
  data: {
    __typename: 'Group',
    group: {
      id: 'gid://gitlab/Group/1',
      complianceFrameworkCoverageSummary: {
        totalProjects: 150,
        coveredCount: 146,
        __typename: 'ComplianceFrameworkCoverageSummary',
      },
      complianceFrameworksCoverageDetails: {
        nodes: Array.from({ length: count }).map((_, idx) => ({
          coveredCount: 6,
          id: `gid://gitlab/ComplianceManagement::FrameworkCoverageDetails/${idx}`,
          framework: {
            id: 'gid://gitlab/ComplianceManagement::Framework/79',
            name: 'Blue framework',
            color: '#6699CC',
            __typename: 'ComplianceFramework',
          },
        })),
      },
    },
  },
});

const generateFailedRequirementsQueryMockResponse = () => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/2857',
      complianceRequirementCoverage: {
        failed: 462,
        passed: 0,
        pending: 0,
        __typename: 'RequirementCoverage',
      },
      __typename: 'Group',
    },
  },
});

const generateFailedControlsQueryMockResponse = () => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/2857',
      complianceRequirementControlCoverage: {
        passed: 231,
        failed: 543,
        pending: 381,
        __typename: 'RequirementControlCoverage',
      },
      __typename: 'Group',
    },
  },
});

const generateFrameworksNeedsAttentionQueryMockResponse = (count = 3) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/2857',
      complianceFrameworksNeedingAttention: {
        nodes: Array.from({ length: count }).map((_, idx) => ({
          id: `gid://gitlab/ComplianceManagement::FrameworkNeedsAttention/${idx}`,
          framework: {
            id: `gid://gitlab/ComplianceManagement::Framework/${idx}`,
            name: `Framework ${idx}`,
            color: '#6699CC',
            scanExecutionPolicies: {
              nodes: [
                {
                  name: `Scan Execution Policy ${idx}`,
                  __typename: 'ScanExecutionPolicy',
                },
              ],
            },
            vulnerabilityManagementPolicies: { nodes: [] },
            scanResultPolicies: { nodes: [] },
            pipelineExecutionPolicies: { nodes: [] },
          },
          projectsCount: 5,
          requirementsCount: 10,
          requirementsWithoutControls: [],
        })),
      },
      __typename: 'Group',
    },
  },
});

describe('Compliance dashboard', () => {
  let wrapper;
  const frameworkCoverageQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));
  const failedRequirementsQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));
  const failedControlsQueryMock = jest.fn().mockImplementation(() => new Promise(() => {}));
  const frameworksNeedsAttentionQueryMock = jest
    .fn()
    .mockImplementation(() => new Promise(() => {}));

  const getDashboardConfig = () => wrapper.findComponent(DashboardLayout).props('config');

  function createComponent() {
    const apolloProvider = createMockApollo([
      [frameworkCoverageQuery, frameworkCoverageQueryMock],
      [failedRequirementsQuery, failedRequirementsQueryMock],
      [failedControlsQuery, failedControlsQueryMock],
      [frameworksNeedsAttentionQuery, frameworksNeedsAttentionQueryMock],
    ]);

    wrapper = shallowMount(ComplianceDashboard, {
      apolloProvider,
      propsData: {
        groupPath: 'root',
        rootAncestorPath: 'root',
      },
    });
  }

  describe('general configuration', () => {
    const frameworkCoverage = generateFrameworkCoverageQueryMockResponse();
    const failedRequirements = generateFailedRequirementsQueryMockResponse();
    const failedControls = generateFailedControlsQueryMockResponse();
    const frameworksNeedsAttention = generateFrameworksNeedsAttentionQueryMockResponse();

    beforeEach(async () => {
      frameworkCoverageQueryMock.mockResolvedValue(frameworkCoverage);
      failedRequirementsQueryMock.mockResolvedValue(failedRequirements);
      failedControlsQueryMock.mockResolvedValue(failedControls);
      frameworksNeedsAttentionQueryMock.mockResolvedValue(frameworksNeedsAttention);
      createComponent();
      await waitForPromises();

      await nextTick();
    });

    it('contains framework coverage panel', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FrameworkCoverage,
          componentProps: {
            summary: {
              totalProjects:
                frameworkCoverage.data.group.complianceFrameworkCoverageSummary.totalProjects,
              coveredCount:
                frameworkCoverage.data.group.complianceFrameworkCoverageSummary.coveredCount,
              details: frameworkCoverage.data.group.complianceFrameworksCoverageDetails.nodes,
            },
            isTopLevelGroup: expect.any(Boolean),
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });

    it('contains failed requirements panel with correct data', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedRequirements,
          componentProps: {
            failedRequirements: failedRequirements.data.group.complianceRequirementCoverage,
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });

    it('contains failed controls panel witch correct data', () => {
      expect(getDashboardConfig().panels).toContainEqual(
        expect.objectContaining({
          component: FailedControls,
          componentProps: {
            failedControls: failedControls.data.group.complianceRequirementControlCoverage,
            colorScheme: getSystemColorScheme(),
          },
        }),
      );
    });

    it('contains frameworks needs attention panel when there are frameworks', () => {
      const { panels } = getDashboardConfig();
      const needsAttentionPanel = panels.find(
        (panel) => panel.component === FrameworksNeedsAttention,
      );

      expect(needsAttentionPanel).toBeDefined();
      expect(needsAttentionPanel.componentProps.frameworks).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: expect.any(String),
            framework: expect.objectContaining({
              name: expect.any(String),
            }),
          }),
        ]),
      );
    });
  });

  describe('framework coverage panel', () => {
    it.each`
      frameworksCount | expectedPanelSize
      ${0}            | ${2}
      ${10}           | ${4}
      ${20}           | ${5}
    `(
      'renders correct size for $frameworksCount frameworks',
      async ({ frameworksCount, expectedPanelSize }) => {
        frameworkCoverageQueryMock.mockResolvedValue(
          generateFrameworkCoverageQueryMockResponse(frameworksCount),
        );
        createComponent();
        await waitForPromises();
        const panelConfig = getDashboardConfig().panels.find(
          (panel) => panel.component === FrameworkCoverage,
        );
        expect(panelConfig.gridAttributes.height).toBe(expectedPanelSize);
      },
    );
  });

  describe('frameworks needs attention panel', () => {
    it('excludes frameworks needs attention panel when there are no frameworks', async () => {
      frameworkCoverageQueryMock.mockResolvedValue(generateFrameworkCoverageQueryMockResponse());
      failedRequirementsQueryMock.mockResolvedValue(generateFailedRequirementsQueryMockResponse());
      failedControlsQueryMock.mockResolvedValue(generateFailedControlsQueryMockResponse());
      frameworksNeedsAttentionQueryMock.mockResolvedValue(
        generateFrameworksNeedsAttentionQueryMockResponse(0),
      );
      createComponent();
      await waitForPromises();

      await nextTick();

      const needsAttentionPanel = getDashboardConfig().panels.find(
        (panel) => panel.component === FrameworksNeedsAttention,
      );
      expect(needsAttentionPanel).toBeUndefined();
    });

    it.each`
      frameworksCount | expectedPanelSize
      ${1}            | ${3.5}
      ${2}            | ${3.5}
      ${3}            | ${3.5}
      ${20}           | ${5.5}
    `(
      'renders correct height for $frameworksCount frameworks needing attention',
      async ({ frameworksCount, expectedPanelSize }) => {
        frameworkCoverageQueryMock.mockResolvedValue(generateFrameworkCoverageQueryMockResponse());
        failedRequirementsQueryMock.mockResolvedValue(
          generateFailedRequirementsQueryMockResponse(),
        );
        failedControlsQueryMock.mockResolvedValue(generateFailedControlsQueryMockResponse());
        frameworksNeedsAttentionQueryMock.mockResolvedValue(
          generateFrameworksNeedsAttentionQueryMockResponse(frameworksCount),
        );
        createComponent();
        await waitForPromises();

        await nextTick();

        const panelConfig = getDashboardConfig().panels.find(
          (panel) => panel.component === FrameworksNeedsAttention,
        );
        expect(panelConfig).toBeDefined();
        expect(panelConfig.gridAttributes.height).toBe(expectedPanelSize);
      },
    );
  });

  describe('when one of the query fails', () => {
    it.each([
      frameworkCoverageQueryMock,
      failedControlsQueryMock,
      failedRequirementsQueryMock,
      frameworksNeedsAttentionQueryMock,
    ])('displays error message', async (queryMock) => {
      queryMock.mockRejectedValue(new Error('Network error'));
      createComponent();
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong on our end.',
      });
    });
  });
});
