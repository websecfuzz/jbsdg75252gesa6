import { mount } from '@vue/test-utils';
import { GlExperimentBadge } from '@gitlab/ui';
import DetailItem from 'ee/vulnerabilities/components/detail_item.vue';

describe('DetailItem', () => {
  let wrapper;

  const defaultProps = {
    sprintfMessage: '%{labelStart}Scanner%{labelEnd}: %{scanner}',
  };

  const createWrapper = (props = {}) => {
    wrapper = mount(DetailItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      slots: {
        default: '<span>Test content</span>',
      },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders correct message', () => {
      expect(wrapper.text()).toBe('Scanner: Test content');
    });

    it('does not render experiment badge by default', () => {
      const experimentBadge = wrapper.findComponent(GlExperimentBadge);
      expect(experimentBadge.exists()).toBe(false);
    });
  });

  describe('with experiment badge', () => {
    beforeEach(() => {
      createWrapper({ showExperimentBadge: true });
    });

    it('renders experiment badge when showExperimentBadge is true', () => {
      const experimentBadge = wrapper.findComponent(GlExperimentBadge);
      expect(experimentBadge.exists()).toBe(true);
    });
  });
});
