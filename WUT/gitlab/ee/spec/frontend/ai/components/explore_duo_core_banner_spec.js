import { GlBanner } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ExploreDuoCoreBanner from 'ee/ai/components/explore_duo_core_banner.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

Vue.use(VueApollo);

describe('ExploreDuoCoreBanner', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createComponent = () => {
    userCalloutDismissSpy = jest.fn();

    wrapper = mountExtended(ExploreDuoCoreBanner, {
      propsData: {
        calloutFeatureName: 'explore_duo_core_banner',
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout: true,
        }),
      },
    });
  };

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findCta = () => wrapper.findByRole('link', { name: 'Explore GitLab Duo Core' });
  const findInstallationLink = () =>
    wrapper.findByRole('link', { name: 'install the GitLab extension in your IDE' });
  const findExploreLink = () =>
    wrapper.findByRole('link', { name: 'explore what you can do with GitLab Duo Core' });

  describe('banner content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('display the correct banner title and body', () => {
      const bannerText = findBanner().text();

      expect(bannerText).toContain('Get started with GitLab Duo');
      expect(bannerText).toContain(
        'You now have access to GitLab Duo Chat and Code Suggestions in supported IDEs. To start using these features',
      );
    });

    it('renders the correct cta button and links', () => {
      expect(findCta().exists()).toBe(true);
      expect(findCta().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/`,
      );

      expect(findInstallationLink().exists()).toBe(true);
      expect(findInstallationLink().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo/#step-4-prepare-to-use-gitlab-duo-in-your-ide`,
      );

      expect(findExploreLink().exists()).toBe(true);
      expect(findExploreLink().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/gitlab_duo/#summary-of-gitlab-duo-features`,
      );
    });
  });

  describe('with dismissal', () => {
    beforeEach(() => {
      createComponent();
    });

    it('dismisses the banner when clicking the close button', () => {
      findBanner().vm.$emit('close');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });

    it('dismisses the banner when clicking the cta', () => {
      findBanner().vm.$emit('primary');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
    });

    it('tracks render_duo_core_banner on mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith('render_duo_core_banner', {}, undefined);
    });

    it('tracks click_cta_link_on_duo_core_banner when clicking CTA button', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      findBanner().vm.$emit('primary');
      await Vue.nextTick();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_cta_link_on_duo_core_banner',
        {},
        undefined,
      );
    });

    it('tracks click_dismiss_button_on_duo_core_banner when closing the banner', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      findBanner().vm.$emit('close');
      await Vue.nextTick();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_dismiss_button_on_duo_core_banner',
        {},
        undefined,
      );
    });

    it('tracks click_extension_link_on_duo_core_banner when clicking the install extension link', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findInstallationLink().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_extension_link_on_duo_core_banner',
        {},
        undefined,
      );
    });

    it('tracks click_explore_link_on_duo_core_banner when clicking the explore duo link', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findExploreLink().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_explore_link_on_duo_core_banner',
        {},
        undefined,
      );
    });
  });
});
