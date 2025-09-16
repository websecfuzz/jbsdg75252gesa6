import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlBanner } from '@gitlab/ui';
import GeoFeedbackBanner from 'ee/geo_replicable/components/geo_feedback_banner.vue';
import { GEO_FEEDBACK_BANNER_DISMISSED_KEY } from 'ee/geo_replicable/constants';

describe('GeoFeedbackBanner', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(GeoFeedbackBanner);
  };

  const findBanner = () => wrapper.findComponent(GlBanner);

  afterEach(() => {
    localStorage.clear();
  });

  describe('when banner is not dismissed', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the banner', () => {
      expect(findBanner().exists()).toBe(true);
    });

    it('displays the correct title', () => {
      expect(findBanner().props('title')).toBe('Your feedback is important to us 👋');
    });

    it('displays the correct button text', () => {
      expect(findBanner().props('buttonText')).toBe('Give us some feedback');
    });

    it('links to the correct feedback issue', () => {
      expect(findBanner().props('buttonLink')).toBe(
        'https://gitlab.com/gitlab-org/gitlab/-/issues/536297',
      );
    });

    it('dismisses the banner when closed', async () => {
      findBanner().vm.$emit('close');
      await nextTick();

      expect(localStorage.getItem(GEO_FEEDBACK_BANNER_DISMISSED_KEY)).toBe('true');
      expect(findBanner().exists()).toBe(false);
    });
  });

  describe('when banner is already dismissed', () => {
    beforeEach(() => {
      localStorage.setItem(GEO_FEEDBACK_BANNER_DISMISSED_KEY, 'true');
      createComponent();
    });

    it('does not render the banner', () => {
      expect(findBanner().exists()).toBe(false);
    });
  });
});
