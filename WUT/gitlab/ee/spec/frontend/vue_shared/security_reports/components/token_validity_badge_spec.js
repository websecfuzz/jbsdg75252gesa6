import { shallowMount } from '@vue/test-utils';
import { GlLabel } from '@gitlab/ui';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

describe('TokenValidityBadge', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(TokenValidityBadge, {
      propsData: {
        ...props,
      },
    });
  };

  const findGlLabel = () => wrapper.findComponent(GlLabel);
  const findHelpPopover = () => wrapper.findComponent(HelpPopover);

  describe('label', () => {
    it.each([
      ['active', '#c91c00', 'Active secret'],
      ['inactive', '#428fdc', 'Inactive secret'],
      ['unknown', '#ececef', 'Possibly active secret'],
    ])('renders correct label for status %s', (status, backgroundColor, title) => {
      createComponent({ status });

      expect(findGlLabel().attributes('data-testid')).toBe('validityCheckLabel');
      expect(findGlLabel().props()).toMatchObject({
        backgroundColor,
        title,
      });
    });

    it('uses unknown status by default', () => {
      createComponent();

      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe('#ececef');
      expect(label.props('title')).toContain('Possibly active secret');

      expect(findGlLabel().attributes('data-testid')).toBe('validityCheckLabel');
      expect(findGlLabel().props()).toMatchObject({
        backgroundColor: '#ececef',
        title: 'Possibly active secret',
      });
    });
  });

  describe('popover', () => {
    it('renders the HelpPopover component', () => {
      createComponent();

      expect(findHelpPopover().props('options')).toEqual({
        title: 'What is a validity check?',
        content:
          'GitLab checks the validity of the secret with the third party vendor on each pipeline run. If the secret is still active it could be exploited and needs to be revoked and rotated.',
      });
    });
  });
});
