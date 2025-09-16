import { GlBanner } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EnableDuoBannerSM from 'ee/ai/components/enable_duo_banner_sm.vue';
import updateAiSettingsMutation from 'ee/ai/graphql/update_ai_settings.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('EnableDuoBanner', () => {
  let wrapper;
  let mockApollo;
  let userCalloutDismissSpy;
  const defaultUpdateAiSettingsMutationHandler = jest.fn().mockResolvedValue({
    data: {
      duoSettingsUpdate: {
        errors: [],
      },
    },
  });

  const provide = {
    bannerTitle: 'AI-native features now available in IDEs',
    licenseTier: 'Ultimate',
    calloutsFeatureName: 'enable_duo_banner',
  };

  const createComponent = ({
    updateAiSettingsMutationHandler = defaultUpdateAiSettingsMutationHandler,
  } = {}) => {
    userCalloutDismissSpy = jest.fn();

    mockApollo = createMockApollo([[updateAiSettingsMutation, updateAiSettingsMutationHandler]]);

    wrapper = mountExtended(EnableDuoBannerSM, {
      apolloProvider: mockApollo,
      provide,
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout: true,
        }),
        ConfirmActionModal,
      },
    });
  };

  afterEach(() => {
    mockApollo = null;
  });

  const findBanner = () => wrapper.findComponent(GlBanner);
  const findModal = () => wrapper.findComponent(ConfirmActionModal);
  const findPrimaryButton = () => wrapper.findByText('Enable GitLab Duo Core');
  const findLearnMoreLink = () => wrapper.findByTestId('enable-duo-banner-learn-more-button');

  describe('banner content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the correct banner title', () => {
      expect(findBanner().text()).toContain('AI-native features now available in IDEs');
    });

    it('displays the correct banner body', () => {
      const bannerText = findBanner().text();

      expect(bannerText).toContain(
        'Code Suggestions and Chat are now available in supported IDEs as part of GitLab Duo Core for all users of your',
      );
      expect(bannerText).toContain('Ultimate');
    });

    it('renders the correct button', () => {
      expect(findPrimaryButton().exists()).toBe(true);
      expect(findLearnMoreLink().exists()).toBe(true);
      expect(findLearnMoreLink().attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/get_started/getting_started_gitlab_duo`,
      );
    });

    describe('when primary button is clicked', () => {
      beforeEach(() => {
        findPrimaryButton().trigger('click');
      });

      it('displays the confirmation modal', () => {
        expect(findModal().exists()).toBe(true);
        expect(findModal().props('title')).toBe('Enable GitLab Duo Core');
        expect(findModal().props('actionText')).toBe('Enable');
      });
    });
  });

  describe('with dismissal', () => {
    it('dismisses the banner when clicking the close button', () => {
      createComponent();

      findBanner().vm.$emit('close');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });

  describe('with confirm modal', () => {
    beforeEach(() => {
      createComponent();
      findPrimaryButton().trigger('click');
    });

    it('calls the updateAiSettingsMutation', () => {
      findModal().vm.performAction();

      expect(defaultUpdateAiSettingsMutationHandler).toHaveBeenCalledWith({
        input: { duoCoreFeaturesEnabled: true },
      });
    });

    it('creates alert and dismisses the banner', async () => {
      findModal().vm.performAction();

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'GitLab Duo Core is now enabled.',
        variant: 'info',
      });
      expect(findBanner().exists()).toBe(false);
    });
  });

  it('create alert when mutation has an error', async () => {
    const mockError = new Error('error');

    createComponent({
      updateAiSettingsMutationHandler: jest.fn().mockResolvedValue({
        data: {
          duoSettingsUpdate: {
            errors: ['error'],
          },
        },
      }),
    });

    await findPrimaryButton().trigger('click');

    findModal().vm.performAction();

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message: 'An error occurred while enabling GitLab Duo Core. Reload the page to try again.',
      error: mockError,
      captureError: true,
    });
  });
});
