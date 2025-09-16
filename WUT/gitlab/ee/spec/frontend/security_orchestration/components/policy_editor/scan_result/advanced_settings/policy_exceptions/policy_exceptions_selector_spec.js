import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyExceptionsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selector.vue';

describe('PolicyExceptionsSelector', () => {
  let wrapper;

  const createComponent = ({ glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(PolicyExceptionsSelector, {
      provide: {
        glFeatures: {
          approvalPolicyBranchExceptions: true,
          securityPoliciesBypassOptionsGroupRoles: true,
          securityPoliciesBypassOptionsTokensAccounts: true,
          ...glFeatures,
        },
      },
    });
  };

  const findPolicyExceptionSelectors = () => wrapper.findAllByTestId('exception-type');
  const findHeaders = () => wrapper.findAllByTestId('exception-type-header');

  describe('all features', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders policy exceptions options', () => {
      expect(findPolicyExceptionSelectors()).toHaveLength(5);
    });

    it('selects policy exceptions option', () => {
      findPolicyExceptionSelectors().at(1).findComponent(GlButton).vm.$emit('click');

      expect(wrapper.emitted('select')).toEqual([['groups']]);
    });
  });

  describe('reduced number of features', () => {
    it('renders partial options list when securityPoliciesBypassOptionsGroupRoles is disabled', () => {
      createComponent({
        glFeatures: {
          securityPoliciesBypassOptionsGroupRoles: false,
        },
      });

      const headers = findHeaders();
      expect(findPolicyExceptionSelectors()).toHaveLength(3);
      expect(headers.at(0).text()).toBe('Service Account');
      expect(headers.at(1).text()).toBe('Access Token');
      expect(headers.at(2).text()).toBe('Source Branch Patterns');
    });

    it('renders partial options list when securityPoliciesBypassOptionsTokensAccounts is disabled', () => {
      createComponent({
        glFeatures: {
          securityPoliciesBypassOptionsTokensAccounts: false,
        },
      });

      const headers = findHeaders();
      expect(findPolicyExceptionSelectors()).toHaveLength(3);
      expect(headers.at(0).text()).toBe('Roles');
      expect(headers.at(1).text()).toBe('Groups');
      expect(headers.at(2).text()).toBe('Source Branch Patterns');
    });

    it('renders only branch patterns option when other two flags are disabled', () => {
      createComponent({
        glFeatures: {
          approvalPolicyBranchExceptions: true,
          securityPoliciesBypassOptionsTokensAccounts: false,
          securityPoliciesBypassOptionsGroupRoles: false,
        },
      });

      const headers = findHeaders();
      expect(findPolicyExceptionSelectors()).toHaveLength(1);
      expect(headers.at(0).text()).toBe('Source Branch Patterns');
    });

    it('renders none of the options when all flags are disabled', () => {
      createComponent({
        glFeatures: {
          approvalPolicyBranchExceptions: false,
          securityPoliciesBypassOptionsTokensAccounts: false,
          securityPoliciesBypassOptionsGroupRoles: false,
        },
      });

      const headers = findHeaders();
      expect(findPolicyExceptionSelectors()).toHaveLength(0);
      expect(headers).toHaveLength(0);
    });
  });
});
