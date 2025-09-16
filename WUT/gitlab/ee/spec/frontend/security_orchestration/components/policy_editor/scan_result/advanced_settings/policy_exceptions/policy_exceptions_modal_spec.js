import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import TokensSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/tokens_selector.vue';
import ServiceAccountsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_selector.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';
import {
  ACCOUNTS,
  SOURCE_BRANCH_PATTERNS,
  TOKENS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import {
  mockAccounts,
  mockBranchPatterns,
  mockTokens,
} from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('PolicyExceptionsModal', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsModal, {
      propsData,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findBranchPatternSelector = () => wrapper.findComponent(BranchPatternSelector);
  const findTokensSelector = () => wrapper.findComponent(TokensSelector);
  const findPolicyExceptionsSelector = () => wrapper.findComponent(PolicyExceptionsSelector);
  const findSaveButton = () => wrapper.findByTestId('save-button');
  const findModalTitle = () => wrapper.findByTestId('modal-title');
  const findModalSubtitle = () => wrapper.findByTestId('modal-subtitle');
  const findServiceAccountsSelector = () => wrapper.findComponent(ServiceAccountsSelector);

  beforeEach(() => {
    createComponent();
  });

  describe('initial state', () => {
    it('renders the modal with correct props', () => {
      const modal = findModal();

      expect(modal.exists()).toBe(true);
      expect(modal.props('size')).toBe('md');
      expect(modal.props('modalId')).toBe('deny-allow-list-modal');

      expect(findPolicyExceptionsSelector().exists()).toBe(true);
    });
  });

  describe('branch patterns', () => {
    it('renders branch pattern selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            branches: mockBranchPatterns,
          },
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      expect(findBranchPatternSelector().exists()).toBe(true);
      expect(findBranchPatternSelector().props('branches')).toEqual(mockBranchPatterns);

      expect(findModalTitle().text()).toBe('Source Branch Patterns');
      expect(findModalSubtitle().text()).toBe(
        'Define branch patterns that can bypass policy requirements using wildcards and regex patterns. Use * for simple wildcards or regex patterns for advanced matching.',
      );
    });

    it('saves selected branch patterns', async () => {
      createComponent({
        propsData: {
          selectedTab: SOURCE_BRANCH_PATTERNS,
        },
      });

      await findBranchPatternSelector().vm.$emit('set-branches', mockBranchPatterns);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            branches: mockBranchPatterns,
          },
        ],
      ]);
    });
  });

  describe('tokens', () => {
    it('renders tokens selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            access_tokens: mockTokens,
          },
          selectedTab: TOKENS,
        },
      });

      expect(findTokensSelector().exists()).toBe(true);
      expect(findTokensSelector().props('selectedTokens')).toEqual(mockTokens);

      expect(findModalTitle().text()).toBe('Access Token');
      expect(findModalSubtitle().text()).toBe(
        'Select instance group or project level access tokens that can bypass this policy.',
      );
    });

    it('saves selected tokens', async () => {
      createComponent({
        propsData: {
          selectedTab: TOKENS,
        },
      });

      await findTokensSelector().vm.$emit('set-access-tokens', mockTokens);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            access_tokens: mockTokens,
          },
        ],
      ]);
    });
  });

  describe('service accounts', () => {
    it('renders service accounts selector', () => {
      createComponent({
        propsData: {
          exceptions: {
            accounts: mockAccounts,
          },
          selectedTab: ACCOUNTS,
        },
      });

      expect(findServiceAccountsSelector().exists()).toBe(true);
      expect(findServiceAccountsSelector().props('selectedAccounts')).toEqual(mockAccounts);

      expect(findModalTitle().text()).toBe('Service Account');
      expect(findModalSubtitle().text()).toBe(
        'Choose which service accounts can bypass this policy.',
      );
    });

    it('saves selected service accounts', async () => {
      createComponent({
        propsData: {
          selectedTab: ACCOUNTS,
        },
      });

      await findServiceAccountsSelector().vm.$emit('set-accounts', mockAccounts);

      expect(wrapper.emitted('changed')).toBeUndefined();

      await findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            accounts: mockAccounts,
          },
        ],
      ]);
    });
  });
});
