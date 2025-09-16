import { nextTick } from 'vue';

import { GlSprintf } from '@gitlab/ui';

import { PROMO_URL } from '~/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import GitlabManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/gitlab_managed_provider_card.vue';
import ClearProjectSettingsModal from 'ee/product_analytics/onboarding/components/providers/clear_project_settings_modal.vue';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
} from '../../../mock_data';

describe('GitlabManagedProviderCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findContactSalesBtn = () => wrapper.findByTestId('contact-sales-team-btn');
  const findConnectGitLabProviderBtn = () =>
    wrapper.findByTestId('connect-gitlab-managed-provider-btn');
  const findRegionAgreementCheckbox = () => wrapper.findByTestId('region-agreement-checkbox');
  const findGcpZoneError = () => wrapper.findByTestId('gcp-zone-error');
  const findClearSettingsModal = () => wrapper.findComponent(ClearProjectSettingsModal);

  const createWrapper = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(GitlabManagedProviderCard, {
      propsData: {
        projectSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        ...props,
      },
      provide: {
        managedClusterPurchased: true,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const initProvider = () => {
    findRegionAgreementCheckbox().vm.$emit('input', true);
    findConnectGitLabProviderBtn().vm.$emit('click');
    return waitForPromises();
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render a title and description', () => {
      expect(wrapper.text()).toContain('GitLab-managed provider');
      expect(wrapper.text()).toContain(
        'Use a GitLab-managed infrastructure to process, store, and query analytics events data.',
      );
    });
  });

  describe('when group does not have product analytics provider purchase', () => {
    beforeEach(() => createWrapper({}, { managedClusterPurchased: false }));

    it('does not show the GitLab-managed provider setup button', () => {
      expect(findConnectGitLabProviderBtn().exists()).toBe(false);
    });

    it('does not show the GCP zone confirmation checkbox', () => {
      expect(findRegionAgreementCheckbox().exists()).toBe(false);
    });

    it('shows a link to contact sales', () => {
      const btn = findContactSalesBtn();
      expect(btn.text()).toBe('Contact our sales team');
      expect(btn.attributes('href')).toBe(`${PROMO_URL}/sales/`);
    });
  });

  describe('when group has product analytics provider purchase', () => {
    describe('when some project provider settings are already configured', () => {
      beforeEach(() => {
        const projectSettings = getPartialProjectLevelAnalyticsProviderSettings();
        createWrapper({
          projectSettings,
        });
      });

      describe('when clicking setup', () => {
        it('should show the clear settings modal', async () => {
          createWrapper({
            projectSettings: getPartialProjectLevelAnalyticsProviderSettings(),
          });

          await initProvider();

          const modal = findClearSettingsModal();
          expect(modal.props('visible')).toBe(true);
          expect(modal.text()).toContain(
            'This project has analytics provider settings configured. If you continue, the settings for projects will be reset so that GitLab-managed provider settings can be used.',
          );
        });

        it('should hide the modal when it emits "hide"', async () => {
          await initProvider();

          findClearSettingsModal().vm.$emit('hide');
          await nextTick();

          expect(findClearSettingsModal().props('visible')).toBe(false);
        });

        it('should select the provider when the modal emits "cleared"', async () => {
          await initProvider();

          await wrapper.setProps({
            projectSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
          });
          findClearSettingsModal().vm.$emit('cleared');
          await nextTick();

          expect(wrapper.emitted('confirm')).toEqual([['file-mock']]);
        });
      });
    });

    describe('when project has no existing settings configured', () => {
      beforeEach(() =>
        createWrapper({
          projectSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        }),
      );

      describe('when initialising without agreeing to region', () => {
        beforeEach(() => {
          findConnectGitLabProviderBtn().vm.$emit('click');
          return waitForPromises();
        });

        it('should show an error', () => {
          expect(findGcpZoneError().text()).toBe(
            'To continue, you must agree to event storage and processing in this region.',
          );
        });

        it('should not emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toBeUndefined();
        });

        describe('when agreeing to region', () => {
          beforeEach(() => {
            const checkbox = findRegionAgreementCheckbox();
            checkbox.vm.$emit('input', true);

            findConnectGitLabProviderBtn().vm.$emit('click');
            return waitForPromises();
          });

          it('should clear the error message', () => {
            expect(findGcpZoneError().exists()).toBe(false);
          });

          it('should emit "confirm" event', () => {
            expect(wrapper.emitted('confirm')).toEqual([['file-mock']]);
          });
        });
      });
    });
  });
});
