import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecurityPolicyViolations from 'ee/vue_merge_request_widget/components/checks/security_policy_violations.vue';

describe('SecurityPolicyViolations merge checks component', () => {
  let wrapper;

  const findActionLink = () => wrapper.findByTestId('extension-actions-button');

  function createComponent({ status = 'SUCCESS', securityPoliciesPath = null } = {}) {
    wrapper = mountExtended(SecurityPolicyViolations, {
      propsData: {
        mr: {
          securityPoliciesPath,
        },
        check: {
          identifier: 'security_policy_violations',
          status,
        },
      },
    });
  }

  it.each`
    status        | path                | exists   | rendersText
    ${'SUCCESS'}  | ${'/security-path'} | ${true}  | ${'renders'}
    ${'SUCCESS'}  | ${''}               | ${false} | ${'does not render'}
    ${'SUCCESS'}  | ${null}             | ${false} | ${'does not render'}
    ${'FAILED'}   | ${'/security-path'} | ${true}  | ${'renders'}
    ${'FAILED'}   | ${''}               | ${false} | ${'does not render'}
    ${'FAILED'}   | ${null}             | ${false} | ${'does not render'}
    ${'INACTIVE'} | ${'/security-path'} | ${false} | ${'does not render'}
    ${'INACTIVE'} | ${''}               | ${false} | ${'does not render'}
    ${'INACTIVE'} | ${null}             | ${false} | ${'does not render'}
  `('$rendersText link to security policies when status is $status', ({ status, path, exists }) => {
    createComponent({ status, securityPoliciesPath: path });

    expect(findActionLink().exists()).toBe(exists);

    if (exists) {
      expect(findActionLink().attributes('href')).toBe(path);
    }
  });
});
