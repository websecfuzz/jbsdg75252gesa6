import { GlBanner } from '@gitlab/ui';
import ChatBubbleSvg from '@gitlab/svgs/dist/illustrations/chat-sm.svg?url';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProductAnalyticsFeedbackBanner from 'ee/analytics/dashboards/components/product_analytics_feedback_banner.vue';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';

import {
  PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID,
  PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK,
} from 'ee/analytics/dashboards/constants';

describe('Product Analytics Feedback Banner', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createWrapper = ({ shouldShowCallout = true } = {}) => {
    userCalloutDismissSpy = jest.fn();
    wrapper = shallowMountExtended(ProductAnalyticsFeedbackBanner, {
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the user callout dismisser component', () => {
      expect(findCalloutDismisser().props('featureName')).toBe(
        PRODUCT_ANALYTICS_DASHBOARD_FEEDBACK_CALLOUT_ID,
      );
    });
  });

  describe('when the callout should be shown', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: true });
    });

    it('renders the banner', () => {
      expect(findBanner().props()).toMatchObject({
        title: 'Tell us what you think!',
        buttonText: 'Give feedback',
        buttonLink: PRODUCT_ANALYTICS_DASHBOARD_SURVEY_LINK,
        dismissLabel: 'Dismiss',
        svgPath: ChatBubbleSvg,
      });
    });

    it('calls the dismiss function on the user callout when the banner is closed', async () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();

      await findBanner().vm.$emit('close');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });

  describe('when the callout should not be shown', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: false });
    });

    it('does not render the banner', () => {
      expect(findBanner().exists()).toBe(false);
    });
  });
});
