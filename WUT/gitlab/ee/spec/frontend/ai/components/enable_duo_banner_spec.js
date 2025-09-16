import { GlBanner, GlModal } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EnableDuoBanner from 'ee/ai/components/enable_duo_banner.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { DOCS_URL_IN_EE_DIR } from '~/constants';
import * as urlUtility from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('EnableDuoBanner', () => {
  let wrapper;
  let mockAxios;

  const provide = {
    bannerTitle: 'Get started with AI-native features',
    learnMoreHref: '/learn_more_link',
    groupId: 1,
    groupPlan: 'Ultimate',
    calloutsPath: '/groups/callouts',
    calloutsFeatureName: 'enable_duo_banner_group_page',
  };

  const createComponent = () => {
    wrapper = mountExtended(EnableDuoBanner, {
      provide,
    });
  };

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findModal = () => wrapper.findComponent(GlModal);
  const findPrimaryButton = () => wrapper.findByText('Enable GitLab Duo Core');
  const findSecondaryButton = () => wrapper.findByText('Learn more');

  describe('banner content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the correct banner title', () => {
      expect(findBanner().text()).toContain('Get started with AI-native features');
    });

    it('displays the correct banner body', () => {
      const bannerText = findBanner().text();

      expect(bannerText).toContain(
        'Code Suggestions and Chat are now available in supported IDEs as part of GitLab Duo Core for all users of your',
      );
      expect(bannerText).toContain('Ultimate');
    });

    it('displays the correct button text', () => {
      expect(findPrimaryButton().exists()).toBe(true);
      expect(findSecondaryButton().exists()).toBe(true);
    });

    describe('when primary button is clicked', () => {
      beforeEach(() => {
        findPrimaryButton().trigger('click');
      });

      it('displays the confirmation modal', () => {
        expect(findModal().exists()).toBe(true);
        expect(findModal().props('title')).toBe('Enable GitLab Duo Core');
        expect(findModal().props('actionPrimary').text).toBe('Enable');
      });
    });

    describe('when secondary button is clicked', () => {
      beforeEach(() => {
        findSecondaryButton().trigger('click');
      });

      it('navigates to the learn more URL when clicked', () => {
        const visitUrlSpy = jest.spyOn(urlUtility, 'visitUrl');

        findSecondaryButton().trigger('click');

        expect(visitUrlSpy).toHaveBeenCalledWith(
          `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo`,
          { external: true },
        );
      });
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    let trackEventSpy;

    beforeEach(() => {
      createComponent();

      const tracking = bindInternalEventDocument(wrapper.element);
      trackEventSpy = tracking.trackEventSpy;
    });

    it('tracks banner view on page load', () => {
      expect(trackEventSpy).toHaveBeenCalledWith('view_enable_duo_banner_pageload', {}, undefined);
    });

    it('tracks primary button clicks', () => {
      findPrimaryButton().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_primary_button_enable_duo_banner',
        {},
        undefined,
      );
    });

    it('sends the dismissEvent when the banner is dismissed', () => {
      mockAxios.onPost(provide.calloutsPath).replyOnce(HTTP_STATUS_OK);

      wrapper.findComponent(GlBanner).vm.$emit('close');

      expect(trackEventSpy).toHaveBeenCalledWith('dismiss_enable_duo_banner', {}, undefined);
    });

    it('tracks secondary button clicks', () => {
      findSecondaryButton().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_secondary_button_enable_duo_banner',
        {},
        undefined,
      );
    });
  });
});
