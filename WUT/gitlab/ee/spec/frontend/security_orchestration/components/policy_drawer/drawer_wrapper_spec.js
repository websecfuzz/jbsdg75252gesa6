import { GlButton, GlDrawer, GlTabs, GlTab } from '@gitlab/ui';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import ScanExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/scan_execution/details_drawer.vue';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockProjectScanExecutionPolicy,
  mockGroupScanExecutionPolicy,
  mockProjectScanExecutionPolicyWithWrapper,
} from '../../mocks/mock_scan_execution_policy_data';

describe('DrawerWrapper component', () => {
  let wrapper;

  const factory = ({
    mountFn = shallowMountExtended,
    propsData,
    stubs = {},
    provide = {},
  } = {}) => {
    wrapper = mountFn(DrawerWrapper, {
      propsData: {
        open: true,
        ...propsData,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        namespacePath: 'gitlab-org',
        ...provide,
      },
      stubs: { YamlEditor: true, ...stubs },
    });
  };

  // Finders
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findPopover = () => wrapper.findByTestId('edit-button-popover');
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findScanExecutionDrawer = () => wrapper.findComponent(ScanExecutionDrawer);
  const findDefaultComponentPolicyEditor = () => wrapper.findComponent(YamlEditor);
  const findTabPolicyEditor = () => wrapper.findByTestId('policy-yaml-editor-tab-content');

  // Shared assertions
  const itRendersEditButton = () => {
    it('renders edit button', () => {
      const button = findEditButton();
      expect(button.exists()).toBe(true);
      expect(button.attributes().href).toBe(
        '/policies/policy-name/edit?type="scan_execution_policy"',
      );
    });
  };

  describe('without a policy', () => {
    beforeEach(() => {
      factory({ stubs: { GlDrawer } });
    });

    it('does not render edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });

  describe('given a generic policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value,
          policy: mockProjectScanExecutionPolicyWithWrapper,
        },
        stubs: {
          YamlEditor,
          GlDrawer,
        },
      });
    });

    it('renders policy editor with manifest', () => {
      expect(findDefaultComponentPolicyEditor().attributes('value')).toBe(
        mockProjectScanExecutionPolicyWithWrapper.yaml,
      );
    });

    itRendersEditButton();

    it('does not render the edit button popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('based on policy permission', () => {
    it.each`
      disableScanPolicyUpdate | expectedResult
      ${true}                 | ${false}
      ${false}                | ${true}
    `('renders edit button', ({ disableScanPolicyUpdate, expectedResult }) => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicy,
          disableScanPolicyUpdate,
        },
        stubs: {
          GlDrawer,
        },
      });

      expect(findEditButton().exists()).toBe(expectedResult);
    });
  });

  describe('given a scanExecution policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicyWithWrapper,
          policyType: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value,
        },
        stubs: {
          GlButton,
          GlDrawer,
          GlTabs,
        },
      });
    });

    it(`renders the scanExecution component`, () => {
      expect(findScanExecutionDrawer().exists()).toBe(true);
    });

    it('renders the tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });

    it('renders the policy editor', () => {
      expect(findTabPolicyEditor().attributes('value')).toBe(
        mockProjectScanExecutionPolicyWithWrapper.yaml,
      );
    });

    itRendersEditButton();
  });

  describe('inherited policy', () => {
    beforeEach(() => {
      factory({
        propsData: {
          policy: mockGroupScanExecutionPolicy,
        },
        stubs: {
          GlDrawer,
        },
      });
    });

    it('renders a disabled edit button', () => {
      const button = findEditButton();
      expect(button.exists()).toBe(true);
      expect(button.props('disabled')).toBe(true);
    });

    it('renders the edit button popover', () => {
      expect(findPopover().exists()).toBe(true);
    });
  });

  describe('policy without source namespace', () => {
    it('should not render popover for policy without namespace', () => {
      factory({
        propsData: {
          policy: {
            ...mockGroupScanExecutionPolicy,
            source: {
              __typename: 'GroupSecurityPolicySource',
              inherited: true,
              namespace: undefined,
            },
          },
        },
      });

      expect(findPopover().exists()).toBe(false);
    });
  });
});
