import { GlLink, GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import RuleName from 'ee/approvals/components/rules/rule_name.vue';

Vue.use(Vuex);

describe('RuleName component', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(RuleName, {
      propsData: {
        ...props,
      },
      provide: {
        coverageCheckHelpPagePath: '/path/to/coverage-check-docs',
      },
    });
  };

  describe.each`
    name                | hasTooltip | hasLink
    ${'Foo'}            | ${false}   | ${false}
    ${'Coverage-Check'} | ${true}    | ${true}
  `('with job name set to $name', ({ name, hasTooltip, hasLink }) => {
    beforeEach(() => {
      createWrapper({ name });
    });

    it(`should ${hasTooltip ? '' : 'not'} render the tooltip`, () => {
      expect(wrapper.findComponent(GlPopover).exists()).toBe(hasTooltip);
      expect(wrapper.findComponent(HelpIcon).exists()).toBe(hasTooltip);
    });

    it(`should ${hasLink ? '' : 'not'} render the tooltip more info link`, () => {
      expect(wrapper.findComponent(GlLink).exists()).toBe(hasLink);
    });

    it('should render the name', () => {
      expect(wrapper.text()).toContain(name);
    });
  });
});
