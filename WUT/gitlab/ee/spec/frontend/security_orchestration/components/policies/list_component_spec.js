import {
  GlBadge,
  GlDisclosureDropdown,
  GlDrawer,
  GlLink,
  GlPopover,
  GlTable,
  GlTooltip,
  GlKeysetPagination,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import * as urlUtils from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import ListComponentScope from 'ee/security_orchestration/components/policies/list_component_scope.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import { goToPolicyMR } from 'ee/security_orchestration/components/policy_editor/utils';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';
import {
  mockScanExecutionPoliciesResponse,
  mockScheduledProjectScanExecutionPolicy,
  mockScheduleScanExecutionPoliciesResponse,
} from '../../mocks/mock_scan_execution_policy_data';
import { mockScanResultPoliciesResponse } from '../../mocks/mock_scan_result_policy_data';

jest.mock('~/alert');

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  goToPolicyMR: jest.fn().mockResolvedValue({ id: '2' }),
}));

const namespacePath = 'path/to/project/or/group';
const defaultAssignedPolicyProject = { fullPath: 'path/to/policy-project', branch: 'main' };
const createGetGroupProjectsCountSpy = (count = 0) =>
  jest.fn().mockResolvedValue({ data: { group: { id: '1', projects: { count } } } });

describe('List component', () => {
  let wrapper;

  const factory =
    (mountFn = mountExtended) =>
    ({ props = {}, provide = {}, groupProjectsCount } = {}) => {
      wrapper = mountFn(ListComponent, {
        propsData: {
          policiesByType: {
            [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
            [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
          },
          ...props,
        },
        provide: {
          disableScanPolicyUpdate: false,
          namespacePath,
          namespaceType: NAMESPACE_TYPES.PROJECT,
          assignedPolicyProject: defaultAssignedPolicyProject,
          maxScanExecutionPolicyActions: 300,
          maxScanExecutionPolicySchedules: 5,
          ...provide,
        },
        apolloProvider: createMockApollo([
          [getGroupProjectsCount, createGetGroupProjectsCountSpy(groupProjectsCount)],
        ]),
        stubs: {
          DrawerWrapper: stubComponent(DrawerWrapper, {
            props: {
              ...DrawerWrapper.props,
              ...GlDrawer.props,
            },
          }),
          NoPoliciesEmptyState: true,
        },
      });

      document.title = 'Test title';
      jest.spyOn(urlUtils, 'updateHistory');
    };
  const mountShallowWrapper = factory(shallowMountExtended);
  const mountWrapper = factory();

  const findActionCells = () => wrapper.findAllByTestId('policy-action-cell');
  const findDisclosureDropdown = (root) => root.findComponent(GlDisclosureDropdown);
  const findSourceFilter = () => wrapper.findByTestId('policy-source-filter');
  const findTypeFilter = () => wrapper.findByTestId('policy-type-filter');
  const findTable = () => wrapper.findComponent(GlTable);
  const findListComponentScope = () => wrapper.findComponent(ListComponentScope);
  const findStatusCells = () => wrapper.findAllByTestId('policy-status-cell');
  const findSourceCells = () => wrapper.findAllByTestId('policy-source-cell');
  const findTypeCells = () => wrapper.findAllByTestId('policy-type-cell');
  const findDrawer = () => wrapper.findByTestId('policyDrawer');
  const findScopeCells = () => wrapper.findAllByTestId('policy-scope-cell');
  const findTooltip = (root) => root.findComponent(GlTooltip);
  const findInheritedPolicyCell = (findMethod) => findMethod().at(1);
  const findInstancePolicyBadge = (cell) => cell.findComponent(GlBadge);
  const findNonInheritedPolicyCell = (findMethod) => findMethod().at(0);
  const findDeleteAction = (root) => root.findAll('button').at(1);
  const findOverloadWarningModal = () => wrapper.findComponent(OverloadWarningModal);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('initial state while loading', () => {
    it('renders closed editor drawer', () => {
      mountShallowWrapper();

      const editorDrawer = findDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props('open')).toBe(false);
      expect(findPagination().exists()).toBe(false);
    });

    it("sets table's loading state", () => {
      mountShallowWrapper({ props: { isLoadingPolicies: true } });

      expect(findTable().attributes('busy')).toBe('true');
    });
  });

  describe('initial state with data', () => {
    let rows;

    describe.each`
      rowIndex | expectedPolicyName                           | expectedPolicyType
      ${1}     | ${mockScanExecutionPoliciesResponse[0].name} | ${'Scan execution'}
      ${3}     | ${mockScanResultPoliciesResponse[0].name}    | ${'Merge request approval'}
    `('policy in row #$rowIndex', ({ rowIndex, expectedPolicyName, expectedPolicyType }) => {
      let row;

      beforeEach(() => {
        mountWrapper();
        rows = wrapper.findAll('tr');
        row = rows.at(rowIndex);
      });

      it(`renders ${expectedPolicyName} in the name cell`, () => {
        expect(row.findAll('td').at(1).text()).toBe(expectedPolicyName);
      });

      it(`renders ${expectedPolicyType} in the policy type cell`, () => {
        expect(row.findAll('td').at(2).text()).toBe(expectedPolicyType);
      });
    });

    it.each`
      type                | filterBy                                     | hiddenTypes
      ${'scan execution'} | ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION} | ${[POLICY_TYPE_FILTER_OPTIONS.APPROVAL]}
      ${'scan result'}    | ${POLICY_TYPE_FILTER_OPTIONS.APPROVAL}       | ${[POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION]}
    `('filtered by $type type', async ({ filterBy, hiddenTypes }) => {
      mountWrapper({ props: { selectedPolicyType: filterBy.value } });
      rows = wrapper.findAll('tr');
      await nextTick();

      expect(findTable().text()).toContain(filterBy.text);
      hiddenTypes.forEach((hiddenType) => {
        expect(findTable().text()).not.toContain(hiddenType.text);
      });
    });

    it('updates url when type filter is selected', () => {
      mountWrapper();
      rows = wrapper.findAll('tr');
      findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        title: 'Test title',
        url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}`,
        replace: true,
      });
    });
  });

  describe('policy drawer', () => {
    beforeEach(() => {
      mountWrapper();
    });

    it('updates the selected policy when `shouldUpdatePolicyList` changes to `true`', async () => {
      findTable().vm.$emit('row-selected', [mockScanExecutionPoliciesResponse[0]]);
      await nextTick();
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(mockScanExecutionPoliciesResponse[0]);
      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(null);
    });

    it('does not update the selected policy when `shouldUpdatePolicyList` changes to `false`', async () => {
      expect(findDrawer().props('policy')).toEqual(null);
      wrapper.setProps({ shouldUpdatePolicyList: false });
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(null);
    });

    it.each`
      type                | policy                                  | policyType
      ${'scan execution'} | ${mockScanExecutionPoliciesResponse[0]} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}
      ${'scan result'}    | ${mockScanResultPoliciesResponse[0]}    | ${POLICY_TYPE_COMPONENT_OPTIONS.approval.value}
    `('renders opened editor drawer for a $type policy', async ({ policy, policyType }) => {
      mountWrapper();
      findTable().vm.$emit('row-selected', [policy]);
      await nextTick();
      await nextTick();
      const editorDrawer = findDrawer();
      expect(editorDrawer.exists()).toBe(true);
      expect(editorDrawer.props()).toMatchObject({
        open: true,
        policy,
        policyType,
      });
    });

    it('should close drawer when new security project is selected', async () => {
      const scanExecutionPolicy = mockScanExecutionPoliciesResponse[0];

      mountWrapper();
      findTable().vm.$emit('row-selected', [scanExecutionPolicy]);
      await nextTick();
      await nextTick();

      expect(findDrawer().props('open')).toEqual(true);
      expect(findDrawer().props('policy')).toEqual(scanExecutionPolicy);

      wrapper.setProps({ shouldUpdatePolicyList: true });
      await nextTick();

      expect(findDrawer().props('open')).toEqual(false);
      expect(findDrawer().props('policy')).toEqual(null);
    });
  });

  describe('columns', () => {
    describe('status', () => {
      beforeEach(() => {
        mountWrapper();
      });

      it('renders a checkmark icon for enabled policies', () => {
        const icon = findStatusCells().at(0).find('svg');

        expect(icon.exists()).toBe(true);
        expect(icon.props()).toMatchObject({
          name: 'check-circle-filled',
          ariaLabel: 'The policy is enabled',
          variant: 'success',
        });
      });

      it('renders a "Disabled" icon for screen readers for disabled policies', () => {
        const icon = findStatusCells().at(2).find('svg');

        expect(icon.exists()).toBe(true);
        expect(icon.props('ariaLabel')).toBe('The policy is disabled');
        expect(icon.props('variant')).toBe('disabled');
      });

      describe('breaking changes icon', () => {
        const expectNoBreakingChangesIcon = () => {
          const icons = findStatusCells().at(0).findAll('svg');
          expect(icons).toHaveLength(1);
          expect(icons.at(0).props('name')).toBe('check-circle-filled');
        };

        const expectRenderedBreakingChangesIcon = ({
          expectedContent,
          expectedLink,
          expectedVariant,
          expectedIconName,
          withLink = true,
        } = {}) => {
          const firstCell = findStatusCells().at(0);
          const icon = firstCell.findAll('svg');
          expect(icon.at(0).props('name')).toBe(expectedIconName);
          expect(icon.at(0).props('variant')).toBe(expectedVariant);
          expect(icon.at(1).props('name')).toBe('error');
          expect(firstCell.findComponent(GlPopover).text()).toBe(expectedContent);
          if (withLink) {
            expect(firstCell.findComponent(GlLink).attributes('href')).toBe(expectedLink);
          }
        };

        it('does not render breaking changes icon when there are no deprecated properties', () => {
          mountWrapper();
          expectNoBreakingChangesIcon();
        });

        it('does not render breaking changes icon when policy type deprecated properties are not supported', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]: [
                  {
                    ...mockPipelineExecutionPoliciesResponse[0],
                    deprecatedProperties: ['test', 'test1'],
                  },
                ],
              },
            },
          });
          expectNoBreakingChangesIcon();
        });

        it('renders breaking changes icon when there are deprecated approval policy properties', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [
                  { ...mockScanResultPoliciesResponse[0], deprecatedProperties: ['test', 'test1'] },
                ],
              },
            },
          });
          expectRenderedBreakingChangesIcon({
            expectedContent:
              'You must edit the policy and replace the deprecated syntax (test, test1). For details on its replacement, see the policy documentation.',
            expectedLink:
              '/help/user/application_security/policies/merge_request_approval_policies#merge-request-approval-policies-schema',
            expectedVariant: 'disabled',
            expectedIconName: 'check-circle-dashed',
          });
        });

        it('renders breaking changes icon when there are deprecated scan execution properties', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                  {
                    ...mockScanExecutionPoliciesResponse[0],
                    deprecatedProperties: ['test'],
                  },
                ],
              },
            },
          });
          expectRenderedBreakingChangesIcon({
            expectedContent: 'Policy contains deprecated syntax (test).',
            expectedLink:
              '/help/user/application_security/policies/scan_execution_policies#scan-execution-policies-schema',
            expectedVariant: 'success',
            expectedIconName: 'check-circle-filled',
          });
        });

        it('renders breaking changes icon when there is exceeding number of scheduled rules', () => {
          mountWrapper({
            props: {
              policiesByType: {
                [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                  mockScheduledProjectScanExecutionPolicy,
                ],
              },
            },
            provide: {
              maxScanExecutionPolicySchedules: 1,
            },
          });

          expectRenderedBreakingChangesIcon({
            expectedContent:
              'A scan execution policy exceeds the limit of 1 scheduled rules per policy. Remove or consolidate rules across policies to reduce the total number of rules.',
            expectedVariant: 'success',
            expectedIconName: 'check-circle-filled',
            withLink: false,
          });
        });
      });
    });

    describe('source', () => {
      it('renders when the policy is not inherited', () => {
        mountWrapper();
        expect(findNonInheritedPolicyCell(findSourceCells).text()).toBe('This project');
      });

      it('renders when the policy is inherited', () => {
        mountWrapper();
        expect(trimText(findInheritedPolicyCell(findSourceCells).text())).toBe(
          'Inherited from parent-group-name',
        );
      });

      it('renders inherited policy without namespace', () => {
        mountWrapper();
        expect(trimText(findInheritedPolicyCell(findSourceCells).text())).toBe(
          'Inherited from parent-group-name',
        );
      });

      it('does not render the instance badge for non-instance policies', () => {
        mountWrapper();
        expect(findInstancePolicyBadge(findSourceCells().at(0)).exists()).toBe(false);
      });

      it('renders the instance badge for instance policies', () => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]: [
                {
                  ...mockPipelineExecutionPoliciesResponse[0],
                  csp: true,
                },
              ],
            },
          },
        });
        expect(findInstancePolicyBadge(findSourceCells().at(0)).exists()).toBe(true);
      });
    });

    describe('scope', () => {
      it.each([NAMESPACE_TYPES.GROUP, NAMESPACE_TYPES.PROJECT])(
        'renders policy scope column inside table on %s level',
        (namespaceType) => {
          mountWrapper({ provide: { namespaceType } });
          expect(findScopeCells()).toHaveLength(4);
          expect(findListComponentScope().exists()).toBe(true);
          expect(findListComponentScope().props()).toEqual({
            isInstanceLevel: false,
            linkedSppItems: [],
            policyScope: expect.objectContaining({ __typename: 'PolicyScope' }),
          });
        },
      );
    });

    describe('actions', () => {
      const EDIT_ACTION = {
        href: '/policies/policy-name/edit?type="scan_execution_policy"',
        text: 'Edit',
      };

      const DELETE_ACTION = {
        action: expect.anything(),
        variant: 'danger',
        text: 'Delete',
      };

      describe('rendering', () => {
        beforeEach(() => {
          mountWrapper();
        });

        it('renders actions column', () => {
          expect(findActionCells()).toHaveLength(4);
        });

        it('renders non-inherited policy actions', () => {
          const policyCell = findNonInheritedPolicyCell(findActionCells);
          expect(findDisclosureDropdown(policyCell).exists()).toBe(true);
          expect(findDisclosureDropdown(policyCell).props('disabled')).toBe(false);
          expect(findTooltip(policyCell).exists()).toBe(false);
        });

        it('renders inherited policy actions', () => {
          const policyCell = findInheritedPolicyCell(findActionCells);
          expect(findDisclosureDropdown(policyCell).exists()).toBe(true);
          expect(findDisclosureDropdown(policyCell).props('disabled')).toBe(true);
          expect(findTooltip(policyCell).exists()).toBe(true);
        });

        it('renders items', () => {
          const policyCell = findNonInheritedPolicyCell(findActionCells);
          expect(findDisclosureDropdown(policyCell).props('items')).toEqual([
            EDIT_ACTION,
            DELETE_ACTION,
          ]);
        });
      });

      describe('group-level rendering', () => {
        beforeEach(() => {
          mountWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
        });

        it('renders items for a group', () => {
          const policyCell = findNonInheritedPolicyCell(findActionCells);
          expect(findDisclosureDropdown(policyCell).props('items')).toEqual([
            EDIT_ACTION,
            DELETE_ACTION,
          ]);
        });
      });

      describe('delete action', () => {
        describe('success', () => {
          beforeEach(async () => {
            mountWrapper();
            const policyCell = findNonInheritedPolicyCell(findActionCells);
            const deleteAction = findDeleteAction(policyCell);
            await deleteAction.trigger('click');
            await waitForPromises();
          });

          it('makes the call to create the merge request', () => {
            expect(goToPolicyMR).toHaveBeenCalledWith(
              expect.objectContaining({
                action: 'REMOVE',
                assignedPolicyProject: {
                  branch: 'main',
                  fullPath: 'path/to/policy-project',
                },
                name: 'Scheduled Dast/SAST scan-project',
                namespacePath: 'path/to/project/or/group',
              }),
            );
          });

          it('sets the table to busy', () => {
            expect(findTable().attributes('aria-busy')).toBe('true');
          });

          it('does not call an alert', () => {
            expect(createAlert).not.toHaveBeenCalled();
          });

          it('does not show the modal', () => {
            expect(findOverloadWarningModal().props('visible')).toBe(false);
          });
        });

        describe('failure', () => {
          const error = { message: 'oops' };

          beforeEach(async () => {
            createAlert.mockClear();
            goToPolicyMR.mockRejectedValue(error);
            mountWrapper();
            const policyCell = findNonInheritedPolicyCell(findActionCells);
            const deleteAction = findDeleteAction(policyCell);
            await deleteAction.trigger('click');
            await waitForPromises();
          });

          it('creates an error', () => {
            expect(createAlert).toHaveBeenCalledWith(error);
          });

          it('sets table to not busy', () => {
            expect(findTable().attributes('aria-busy')).toBe('false');
          });
        });

        describe('group', () => {
          describe.each`
            title                                                   | groupProjectsCount | hasScheduleScanPolicy
            ${'w/out schedule scan and w/out performance concerns'} | ${0}               | ${false}
            ${'w/out schedule scan and w performance concerns'}     | ${1001}            | ${false}
            ${'w/ schedule scan and w/out performance concerns'}    | ${0}               | ${true}
          `('$title', ({ groupProjectsCount, hasScheduleScanPolicy }) => {
            it('makes the call to create the merge request', async () => {
              const props = hasScheduleScanPolicy
                ? {
                    policiesByType: {
                      [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
                        mockScheduleScanExecutionPoliciesResponse,
                    },
                  }
                : {};
              mountWrapper({
                props,
                provide: { namespaceType: NAMESPACE_TYPES.GROUP },
                groupProjectsCount,
              });
              const policyCell = findNonInheritedPolicyCell(findActionCells);
              const deleteAction = findDeleteAction(policyCell);
              await deleteAction.trigger('click');
              await waitForPromises();
              expect(goToPolicyMR).toHaveBeenCalledWith(
                expect.objectContaining({
                  action: 'REMOVE',
                  assignedPolicyProject: {
                    branch: 'main',
                    fullPath: 'path/to/policy-project',
                  },
                  name: 'Scheduled Dast/SAST scan-project',
                  namespacePath: 'path/to/project/or/group',
                }),
              );
            });
          });

          describe('w/ schedule scan and w/ performance concerns', () => {
            beforeEach(async () => {
              mountWrapper({
                props: {
                  policiesByType: {
                    [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]:
                      mockScheduleScanExecutionPoliciesResponse,
                  },
                },
                provide: { namespaceType: NAMESPACE_TYPES.GROUP },
                groupProjectsCount: 1001,
              });
              await waitForPromises();
              const policyCell = findNonInheritedPolicyCell(findActionCells);
              const deleteAction = findDeleteAction(policyCell);
              await deleteAction.trigger('click');
              await waitForPromises();
            });

            it('shows the performance concern modal and does not make the call to create the merge request', () => {
              expect(goToPolicyMR).not.toHaveBeenCalled();
              expect(findOverloadWarningModal().props('visible')).toBe(true);
            });

            it('does make the call to create the merge request after confirming the modal', async () => {
              await findOverloadWarningModal().vm.$emit('confirm-submit');
              expect(goToPolicyMR).toHaveBeenCalledWith(
                expect.objectContaining({
                  action: 'REMOVE',
                  assignedPolicyProject: {
                    branch: 'main',
                    fullPath: 'path/to/policy-project',
                  },
                  name: 'Scheduled Dast/SAST scan-project',
                  namespacePath: 'path/to/project/or/group',
                }),
              );
            });

            it('does not make the call to create the merge request after cancelling the modal', async () => {
              await findOverloadWarningModal().vm.$emit('cancel-submit');
              expect(goToPolicyMR).not.toHaveBeenCalled();
            });
          });
        });
      });
    });
  });

  describe('filters', () => {
    describe('type', () => {
      beforeEach(() => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                mockScanExecutionPoliciesResponse[1],
              ],
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [mockScanResultPoliciesResponse[1]],
            },
          },
        });
        findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value);
      });

      it('emits when the type filter is changed', () => {
        expect(wrapper.emitted('update-policy-type')).toEqual([
          [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value],
        ]);
      });

      it.each`
        value
        ${POLICY_TYPE_FILTER_OPTIONS.ALL.value}
        ${POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value}
      `('should select type filter value $value parameters are in url', ({ value }) => {
        mountWrapper({ props: { selectedPolicyType: value } });
        expect(findSourceFilter().props('value')).toBe(POLICY_SOURCE_OPTIONS.ALL.value);
        expect(findTypeFilter().props('value')).toBe(value);
      });

      it('updates url when type filter is selected', () => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
              [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
                mockPipelineExecutionPoliciesResponse,
            },
          },
        });

        findTypeFilter().vm.$emit('input', POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value);

        expect(urlUtils.updateHistory).toHaveBeenCalledWith({
          title: 'Test title',
          url: `http://test.host/?type=${POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value}`,
          replace: true,
        });
      });
    });

    describe('source', () => {
      beforeEach(() => {
        mountWrapper({
          props: {
            policiesByType: {
              [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: [
                mockScanExecutionPoliciesResponse[1],
              ],
              [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: [mockScanResultPoliciesResponse[1]],
            },
          },
        });
        findSourceFilter().vm.$emit('input', POLICY_SOURCE_OPTIONS.INHERITED.value);
      });

      it('displays inherited policies only', () => {
        expect(findSourceCells()).toHaveLength(2);
        expect(trimText(findSourceCells().at(0).text())).toBe('Inherited from parent-group-name');
        expect(trimText(findSourceCells().at(1).text())).toBe('Inherited from parent-group-name');
      });

      it('updates url when source filter is selected', () => {
        expect(urlUtils.updateHistory).toHaveBeenCalledWith({
          title: 'Test title',
          url: `http://test.host/?source=${POLICY_SOURCE_OPTIONS.INHERITED.value}`,
          replace: true,
        });
      });

      it('displays inherited scan execution policies', () => {
        expect(trimText(findTypeCells().at(0).text())).toBe(
          POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
        );
      });

      it('displays inherited scan result policies', () => {
        expect(trimText(findTypeCells().at(1).text())).toBe(
          POLICY_TYPE_FILTER_OPTIONS.APPROVAL.text,
        );
      });

      it.each`
        value
        ${POLICY_SOURCE_OPTIONS.DIRECT.value}
        ${POLICY_SOURCE_OPTIONS.INHERITED.value}
      `('should select source filter value $value when parameters are in url', ({ value }) => {
        mountWrapper({ props: { selectedPolicySource: value } });
        expect(findSourceFilter().props('value')).toBe(value);
        expect(findTypeFilter().props('value')).toBe(POLICY_TYPE_FILTER_OPTIONS.ALL.value);
      });

      it('emits when the source filter is changed', () => {
        expect(wrapper.emitted('update-policy-source')).toEqual([
          [POLICY_SOURCE_OPTIONS.INHERITED.value],
        ]);
      });
    });
  });

  describe('pagination', () => {
    it.each(['hasNextPage', 'hasPreviousPage'])(
      'renders pagination when pagination has next or previous page',
      (pageKey) => {
        mountShallowWrapper({
          props: { pageInfo: { [pageKey]: true } },
          provide: {
            glFeatures: {
              securityPoliciesCombinedList: true,
            },
          },
        });

        expect(findPagination().exists()).toBe(true);
      },
    );

    it('emits next and previous page events', async () => {
      mountWrapper({
        props: { pageInfo: { hasNextPage: true, startCursor: 'start', endCursor: 'end' } },
        provide: {
          glFeatures: {
            securityPoliciesCombinedList: true,
          },
        },
      });

      await findPagination().vm.$emit('next');

      expect(wrapper.emitted('next-page')).toHaveLength(1);

      await findPagination().vm.$emit('prev');

      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });
  });
});
