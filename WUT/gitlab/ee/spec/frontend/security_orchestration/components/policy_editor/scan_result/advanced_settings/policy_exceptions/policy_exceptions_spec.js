import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions.vue';
import PolicyExceptionsModal from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_modal.vue';
import PolicyExceptionsSelectedList from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions_selected_list.vue';
import { mockBranchPatterns } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('PolicyExceptions', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(PolicyExceptions, {
      propsData,
      stubs: { PolicyExceptionsModal },
    });
  };

  const findAddButton = () => wrapper.findComponent(GlButton);
  const findExceptionsModal = () => wrapper.findComponent(PolicyExceptionsModal);
  const findPolicyExceptionsSelectedList = () =>
    wrapper.findComponent(PolicyExceptionsSelectedList);

  describe('initial rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders add button and exceptions modal', () => {
      expect(findAddButton().exists()).toBe(true);
      expect(findExceptionsModal().exists()).toBe(true);
      expect(findExceptionsModal().findComponent(GlModal).props('visible')).toBe(false);
      expect(findPolicyExceptionsSelectedList().exists()).toBe(false);
    });
  });

  describe('selected exceptions', () => {
    const mockSelectedExceptions = {
      roles: ['maintainer', 'developer'],
      branches: mockBranchPatterns,
      groups: [{ id: 1, name: 'group1' }],
    };

    it('renders list of selected exceptions', () => {
      createComponent({
        propsData: {
          exceptions: mockSelectedExceptions,
        },
      });

      expect(findPolicyExceptionsSelectedList().exists()).toBe(true);
      expect(findPolicyExceptionsSelectedList().props('selectedExceptions')).toEqual(
        mockSelectedExceptions,
      );
    });

    it('removes selected exceptions', () => {
      createComponent({
        propsData: {
          exceptions: mockSelectedExceptions,
        },
      });

      findPolicyExceptionsSelectedList().vm.$emit('remove', 'branches');
      expect(wrapper.emitted('changed')).toEqual([
        [
          'bypass_settings',
          { roles: ['maintainer', 'developer'], groups: [{ id: 1, name: 'group1' }] },
        ],
      ]);
    });
  });
});
