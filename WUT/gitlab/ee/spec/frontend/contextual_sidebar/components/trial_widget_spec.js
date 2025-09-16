import { GlProgressBar } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrialWidget from 'ee/contextual_sidebar/components/trial_widget.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('TrialWidget component', () => {
  let wrapper;

  const findRootElement = () => wrapper.findByTestId('trial-widget-root-element');
  const findWidgetTitle = () => wrapper.findByTestId('widget-title');
  const findCTAButton = () => wrapper.findByTestId('widget-cta');

  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findDismissButton = () => wrapper.findByTestId('dismiss-btn');

  const provide = {
    trialType: 'duo_enterprise',
    daysRemaining: 40,
    percentageComplete: 33,
    trialDiscoverPagePath: '/discover',
    groupId: '1',
    featureId: '2',
    dismissEndpoint: '/dismiss',
    purchaseNowUrl: '/purchase',
  };

  const createComponent = (providers = {}) => {
    wrapper = shallowMountExtended(TrialWidget, {
      provide: {
        ...provide,
        ...providers,
      },
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  describe('rendered content', () => {
    it('renders with the correct id', () => {
      createComponent();
      expect(findRootElement().attributes('id')).toBe('trial-sidebar-widget');
    });

    it('shows the expected days remaining text when trial is active', () => {
      createComponent({ daysRemaining: 30, percentageComplete: 50 });
      expect(wrapper.text()).toContain('30 days left in trial');
    });

    it('does not render the dismiss button during active trial', () => {
      createComponent({ percentageComplete: 50 });
      expect(findDismissButton().exists()).toBe(false);
    });

    describe('when trial is active', () => {
      beforeEach(() => {
        createComponent({ daysRemaining: 30, percentageComplete: 50 });
      });

      it('renders the progress bar', () => {
        expect(findProgressBar().exists()).toBe(true);
      });

      it('renders the CTA button', () => {
        expect(findCTAButton().exists()).toBe(true);
      });

      describe('when under the threshold days', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 20, percentageComplete: 67 });
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });
      });

      describe('when on the last day of the trial', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 1, percentageComplete: 98 });
        });

        it('renders the progress bar', () => {
          expect(findProgressBar().exists()).toBe(true);
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });
      });

      describe('when trial has expired', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 0, percentageComplete: 100 });
        });

        it('shows correct body', () => {
          expect(wrapper.text()).toContain('Your trial of GitLab Duo Enterprise has ended');
        });

        it('renders the progress bar', () => {
          expect(findProgressBar().exists()).toBe(true);
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });

        it('renders the dismiss button', () => {
          expect(findDismissButton().exists()).toBe(true);
        });

        describe('dismissal', () => {
          let mockAxios;

          beforeEach(() => {
            mockAxios = new MockAdapter(axios);
          });

          afterEach(() => {
            mockAxios.restore();
          });

          it('should close the widget when dismiss is clicked', async () => {
            mockAxios.onPost(provide.dismissEndpoint).replyOnce(HTTP_STATUS_OK);
            expect(findRootElement().exists()).toBe(true);
            findDismissButton().vm.$emit('click');

            await waitForPromises();
            expect(findRootElement().exists()).toBe(false);
          });

          it('should close the widget and send sentry the exception on backend persistence failure', async () => {
            mockAxios
              .onPost(provide.dismissEndpoint)
              .replyOnce(HTTP_STATUS_BAD_REQUEST, { message: 'bad_request' });
            expect(findRootElement().exists()).toBe(true);
            findDismissButton().vm.$emit('click');

            await waitForPromises();
            expect(findRootElement().exists()).toBe(false);
            expect(Sentry.captureException).toHaveBeenCalledWith(
              new Error('Request failed with status code 400'),
            );
          });

          it('should track the dismiss event', () => {
            const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

            findDismissButton().vm.$emit('click');

            expect(trackEventSpy).toHaveBeenCalledWith(
              'click_dismiss_button_on_trial_widget',
              {
                label: 'gitlab_duo_enterprise',
              },
              undefined,
            );
          });
        });
      });
    });
  });

  describe('widget title', () => {
    it.each([
      ['duo_pro', 'GitLab Duo Pro Trial', 'Your trial of GitLab Duo Pro has ended'],
      [
        'duo_enterprise',
        'GitLab Duo Enterprise Trial',
        'Your trial of GitLab Duo Enterprise has ended',
      ],
      [
        'ultimate',
        'Ultimate with GitLab Duo Enterprise Trial',
        'Your trial of Ultimate with GitLab Duo Enterprise has ended',
      ],
    ])('renders correctly for %s', (trialType, activeTitle, expiredTitle) => {
      createComponent({ trialType, daysRemaining: 30, percentageComplete: 50 });
      expect(findWidgetTitle().text()).toBe(activeTitle);

      createComponent({ trialType, daysRemaining: 0, percentageComplete: 100 });
      expect(findWidgetTitle().text()).toBe(expiredTitle);
    });
  });

  describe('when trial is active', () => {
    beforeEach(() => {
      createComponent({ daysRemaining: 30, percentageComplete: 50 });
    });

    it('renders the progress bar', () => {
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the CTA button', () => {
      expect(findCTAButton().exists()).toBe(true);
    });
  });

  describe('when trial has expired', () => {
    it.each([
      ['duo_pro', 'Your trial of GitLab Duo Pro has ended'],
      ['duo_enterprise', 'Your trial of GitLab Duo Enterprise has ended'],
      ['ultimate', 'Your trial of Ultimate with GitLab Duo Enterprise has ended'],
    ])('shows correct title and upgrade text for %s', (trialType, expiredTitle) => {
      createComponent({ trialType, daysRemaining: -1, percentageComplete: 110 });

      expect(findWidgetTitle().text()).toBe(expiredTitle);
    });

    it('renders the progress bar', () => {
      createComponent({ daysRemaining: 0, percentageComplete: 100 });
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the dismiss button', () => {
      createComponent({ daysRemaining: 0, percentageComplete: 100 });
      expect(findDismissButton().exists()).toBe(true);
    });
  });
});
