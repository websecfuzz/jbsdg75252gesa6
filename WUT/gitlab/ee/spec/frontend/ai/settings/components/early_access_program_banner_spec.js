import { shallowMount } from '@vue/test-utils';
import { GlBanner } from '@gitlab/ui';
import EarlyAccessProgramBanner, {
  EARLY_ACCESS_BANNER_COOKIE_KEY,
} from 'ee/ai/settings/components/early_access_program_banner.vue';
import { getCookie, setCookie } from '~/lib/utils/common_utils';
import showToast from '~/vue_shared/plugins/global_toast';

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
  setCookie: jest.fn(),
  parseBoolean: jest.fn((val) => val === 'true'),
}));

jest.mock('~/vue_shared/plugins/global_toast');

describe('EarlyAccessProgramBanner', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMount(EarlyAccessProgramBanner, {
      propsData: props,
      provide: {
        earlyAccessPath: '/early_access_opt_in',
        ...provide,
      },
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);

  describe('when banner not been dismissed', () => {
    beforeEach(() => {
      getCookie.mockReturnValue('false');
      createComponent();
    });

    it('renders the banner', () => {
      expect(findBanner().exists()).toBe(true);
    });

    it('sets correct props on GlBanner', () => {
      expect(findBanner().props()).toMatchObject({
        title: 'Participate in the Early Access Program and help make GitLab better',
        buttonText: 'Enroll in the Early Access Program',
        buttonLink: '/early_access_opt_in',
        svgPath: null,
        variant: 'introduction',
      });
    });

    describe('dismissBanner', () => {
      beforeEach(async () => {
        await findBanner().vm.$emit('close');
      });

      it('sets the cookie when banner is dismissed', () => {
        expect(setCookie).toHaveBeenCalledWith(EARLY_ACCESS_BANNER_COOKIE_KEY, 'true', {
          expires: 7,
        });
      });

      it('hides the banner when dismissed', () => {
        expect(findBanner().exists()).toBe(false);
      });

      it('shows a toast message when banner is dismissed', () => {
        expect(showToast).toHaveBeenCalledWith(
          'Early Access Program banner dismissed. You will not see it again for 7 days.',
        );
      });
    });
  });

  describe('when banner has been dismissed', () => {
    it('does not render the banner', () => {
      getCookie.mockReturnValue('true');
      createComponent();
      expect(findBanner().exists()).toBe(false);
    });
  });
});
