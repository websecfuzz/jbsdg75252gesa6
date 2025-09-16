import { GlPopover, GlSprintf, GlLink, GlIcon } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyOverrideWarningIcon from 'ee/approvals/components/approval_settings/policy_override_warning_icon.vue';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  REQUIRE_PASSWORD_TO_APPROVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { mockProjectApprovalSettingsScanResultPolicy } from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import securityOrchestrationModule from 'ee/approvals/stores/modules/security_orchestration';
import createStore from 'ee/approvals/stores';
import { gqClient } from 'ee/security_orchestration/utils';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(Vuex);

const policiesQueryResponse = {
  data: {
    namespace: {
      scanResultPolicies: {
        nodes: [mockProjectApprovalSettingsScanResultPolicy],
      },
    },
  },
};
const emptyPoliciesQueryResponse = { data: { project: { scanResultPolicies: { nodes: [] } } } };

describe('PolicyOverrideWarningIcon', () => {
  let wrapper;
  let store;
  let actions;
  const fullPath = 'full/path';

  const scanResultPoliciesWithoutApprovalSettings = [{ name: 'policy 1', enabled: true }];
  const scanResultPoliciesWithEmptyApprovalSettings = [
    { name: 'policy 1', enabled: true, approval_settings: {} },
  ];
  const scanResultPoliciesDisabled = [
    { name: 'policy 1', enabled: false, approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true } },
  ];
  const scanResultPoliciesWithoutMergeRequestApprovalSettings = [
    { name: 'policy 1', enabled: true, approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } },
  ];
  const scanResultPoliciesWithApprovalSettings = [
    {
      name: 'policy 1',
      enabled: true,
      approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true },
      editPath: 'link 1',
    },
    {
      name: 'policy 2',
      enabled: true,
      approval_settings: { [REQUIRE_PASSWORD_TO_APPROVE]: true },
      editPath: 'link 2',
    },
  ];

  const setupStore = (scanResultPolicies = []) => {
    const module = securityOrchestrationModule();

    actions = module.actions;
    store = createStore({
      securityOrchestrationModule: module,
    });
    store.state.securityOrchestrationModule.scanResultPolicies = scanResultPolicies;
  };

  const createComponent = ({ provideData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyOverrideWarningIcon, {
      store,
      stubs: {
        GlPopover,
        GlSprintf,
      },
      provide: {
        fullPath,
        ...provideData,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLink = () => wrapper.findComponent(GlLink);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPolicyItem = (index) => wrapper.findByTestId(`policy-item-${index}`);

  afterEach(() => {
    store = null;
  });

  describe('fetchScanResultPolicies', () => {
    beforeEach(() => {
      setupStore();
    });

    it('fetches scanResultPolicies from API', () => {
      jest.spyOn(actions, 'fetchScanResultPolicies').mockImplementation();
      setupStore();
      createComponent();

      expect(actions.fetchScanResultPolicies).toHaveBeenCalledWith(expect.any(Object), {
        fullPath,
        isGroup: false,
      });
    });

    it('fetches group scanResultPolicies from API when isGroup is injected and is true', () => {
      jest.spyOn(actions, 'fetchScanResultPolicies').mockImplementation();
      setupStore();
      createComponent({ provideData: { isGroup: true } });

      expect(actions.fetchScanResultPolicies).toHaveBeenCalledWith(expect.any(Object), {
        fullPath,
        isGroup: true,
      });
    });
  });

  describe('initial rendering based on queried data', () => {
    it('does not render the icon without policies', async () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(emptyPoliciesQueryResponse);
      setupStore();
      createComponent();
      await waitForPromises();

      expect(findIcon().exists()).toBe(false);
    });

    it('renders the icon with policies', async () => {
      jest.spyOn(gqClient, 'query').mockResolvedValue(policiesQueryResponse);
      setupStore();
      createComponent();
      await waitForPromises();

      expect(findIcon().props('name')).toBe('warning');
    });
  });

  it.each`
    scanResultPolicies                                       | expectedExists
    ${[]}                                                    | ${false}
    ${scanResultPoliciesDisabled}                            | ${false}
    ${scanResultPoliciesWithoutApprovalSettings}             | ${false}
    ${scanResultPoliciesWithoutMergeRequestApprovalSettings} | ${false}
    ${scanResultPoliciesWithEmptyApprovalSettings}           | ${false}
    ${scanResultPoliciesWithApprovalSettings}                | ${true}
  `('renders based on scan result policies', ({ scanResultPolicies, expectedExists }) => {
    setupStore(scanResultPolicies);
    createComponent();

    expect(findIcon().exists()).toBe(expectedExists);
  });

  it('renders warning icon and popover for multiple policies', () => {
    setupStore(scanResultPoliciesWithApprovalSettings);
    createComponent();

    expect(findIcon().props('name')).toBe('warning');
    expect(findPopover().text()).toContain(
      'Some settings may be affected by the following policies',
    );

    expect(findPolicyItem(0).text()).toBe('policy 1');
    expect(findPolicyItem(1).text()).toBe('policy 2');
    expect(findPolicyItem(0).findComponent(GlLink).attributes('href')).toBe('link 1');
    expect(findPolicyItem(1).findComponent(GlLink).attributes('href')).toBe('link 2');
  });

  it('renders warning icon and popover for single policy', () => {
    setupStore([scanResultPoliciesWithApprovalSettings[0]]);
    createComponent();

    expect(findIcon().props('name')).toBe('warning');
    expect(findPopover().text()).toContain('Some settings may be affected by policy');
    expect(findPopover().text()).toContain('policy 1');
    expect(findLink().attributes('href')).toBe('link 1');
  });
});
