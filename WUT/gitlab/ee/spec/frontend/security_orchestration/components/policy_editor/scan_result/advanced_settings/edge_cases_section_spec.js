import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlPopover } from '@gitlab/ui';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';

describe('EdgeCasesSection', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(EdgeCasesSection, {
      propsData: { policyTuning: { unblock_rules_using_execution_policies: false }, ...propsData },
    });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('default state when edge cases setting is not selected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the checkbox', () => {
      expect(findCheckbox().text()).toContain(
        'Make approval rules optional using execution policies',
      );
      expect(findCheckbox().attributes('checked')).toBeUndefined();
    });

    it('renders the popover', () => {
      expect(findPopover().exists()).toBe(true);
    });

    it('emits when a checkbox is clicked', () => {
      findCheckbox().vm.$emit('change', true);
      expect(wrapper.emitted('changed')).toEqual([
        ['policy_tuning', { unblock_rules_using_execution_policies: true }],
      ]);
    });
  });

  describe('when edge cases setting is selected', () => {
    it('renders the selected checkbox when YAML value is enabled', () => {
      createComponent({ policyTuning: { unblock_rules_using_execution_policies: true } });
      expect(findCheckbox().attributes('checked')).toBe('true');
    });
  });
});
