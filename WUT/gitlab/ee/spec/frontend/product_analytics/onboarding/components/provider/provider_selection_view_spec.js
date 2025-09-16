import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { visitUrl } from '~/lib/utils/url_utility';

import getProductAnalyticsProjectSettings from 'ee/product_analytics/graphql/queries/get_product_analytics_project_settings.query.graphql';
import initializeProductAnalyticsMutation from 'ee/product_analytics/graphql/mutations/initialize_product_analytics.mutation.graphql';
import ProviderSelectionView from 'ee/product_analytics/onboarding/components/providers/provider_selection_view.vue';
import GitLabManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/gitlab_managed_provider_card.vue';
import SelfManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/self_managed_provider_card.vue';

import {
  createInstanceResponse,
  getEmptyProjectLevelAnalyticsProviderSettings,
  getProductAnalyticsProjectSettingsResponse,
} from '../../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

Vue.use(VueApollo);

describe('ProviderSelectionView', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const fatalError = new Error('GraphQL networkError');
  const apiErrorMsg = 'Product analytics initialization is already complete';
  const mockCreateInstanceSuccess = jest.fn().mockResolvedValue(createInstanceResponse([]));
  const mockCreateInstanceError = jest
    .fn()
    .mockResolvedValue(createInstanceResponse([apiErrorMsg]));
  const mockCreateInstanceFatalError = jest.fn().mockRejectedValue(fatalError);
  const getProductAnalyticsSettingsMock = jest
    .fn()
    .mockResolvedValue(getProductAnalyticsProjectSettingsResponse());

  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findInstanceLoadingState = () =>
    wrapper.findByTestId('provider-selection-instance-loading');
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findProviderCardSkeletonLoaders = () =>
    wrapper.findAllByTestId('provider-card-skeleton-loader');
  const findSelfManagedProviderCard = () => wrapper.findComponent(SelfManagedProviderCard);
  const findGitLabManagedProviderCard = () => wrapper.findComponent(GitLabManagedProviderCard);
  const findErrorAlert = () => wrapper.findByTestId('provider-settings-error-alert');

  const createWrapper = (createInstanceMock = mockCreateInstanceSuccess, provide = {}) => {
    wrapper = shallowMountExtended(ProviderSelectionView, {
      apolloProvider: createMockApollo([
        [initializeProductAnalyticsMutation, createInstanceMock],
        [getProductAnalyticsProjectSettings, getProductAnalyticsSettingsMock],
      ]),
      propsData: {
        loadingInstance: false,
      },
      provide: {
        analyticsSettingsPath: '/settings/analytics',
        canSelectGitlabManagedProvider: true,
        namespaceFullPath: 'group/project',
        projectLevelAnalyticsProviderSettings: {},
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('default behaviour', () => {
    describe('while project settings are loading', () => {
      beforeEach(() => createWrapper());

      it('should render a description', () => {
        expect(wrapper.text()).toContain(
          'Set up Product Analytics to track how your product is performing. Combine analytics with your GitLab data to better understand where you can improve your product and development processes.',
        );
      });

      it('should show provider cards loading state', () => {
        expect(findProviderCardSkeletonLoaders()).toHaveLength(2);

        expect(findSelfManagedProviderCard().exists()).toBe(false);
        expect(findGitLabManagedProviderCard().exists()).toBe(false);
      });

      it('does not render the instance loading state', () => {
        expect(findInstanceLoadingState().exists()).toBe(false);
      });

      it('renders the help link', () => {
        expect(findHelpLink().attributes('href')).toBe(
          '/help/development/internal_analytics/product_analytics#onboard-a-gitlab-project',
        );
      });
    });

    describe('once project settings have loaded', () => {
      describe('when response is successful', () => {
        let projectSettings;

        beforeEach(() => {
          projectSettings = getEmptyProjectLevelAnalyticsProviderSettings();
          getProductAnalyticsSettingsMock.mockResolvedValue(
            getProductAnalyticsProjectSettingsResponse(projectSettings),
          );
          createWrapper();
          return waitForPromises();
        });

        it('should show provider cards', () => {
          expect(findProviderCardSkeletonLoaders()).toHaveLength(0);

          expect(findSelfManagedProviderCard().props()).toStrictEqual(
            expect.objectContaining({ projectSettings }),
          );
          expect(findGitLabManagedProviderCard().props()).toStrictEqual(
            expect.objectContaining({ projectSettings }),
          );
        });
      });

      describe('when response is unsuccessful', () => {
        const error = new Error('Oh no project settings failed to load!');

        beforeEach(() => {
          getProductAnalyticsSettingsMock.mockRejectedValue(error);
          createWrapper();
          return waitForPromises();
        });

        it('displays an error message', () => {
          expect(findErrorAlert().text()).toBe(
            'An error occurred while fetching project settings. Refresh the page to try again.',
          );
        });

        it('does not render a title mentioning options', () => {
          expect(wrapper.text()).not.toContain('Select an option');
        });

        it('does not render the Self-managed provider card', () => {
          expect(findSelfManagedProviderCard().exists()).toBe(false);
        });

        it('does not render the GitLab-managed provider card', () => {
          expect(findGitLabManagedProviderCard().exists()).toBe(false);
        });
      });
    });
  });

  describe('when GitLab-managed provider is unavailable', () => {
    beforeEach(() => {
      createWrapper(mockCreateInstanceSuccess, { canSelectGitlabManagedProvider: false });
    });

    it('does not render a title mentioning options', () => {
      expect(wrapper.text()).not.toContain('Select an option');
    });

    it('does not render the GitLab-managed provider card', () => {
      expect(findGitLabManagedProviderCard().exists()).toBe(false);
    });
  });

  describe.each`
    scenario            | findComponent                    | loadingStateSvgPath
    ${'self-managed'}   | ${findSelfManagedProviderCard}   | ${'/self-managed.svg'}
    ${'GitLab-managed'} | ${findGitLabManagedProviderCard} | ${'/gitlab-managed.svg'}
  `('$scenario', ({ findComponent, loadingStateSvgPath }) => {
    describe('when component emits "confirm" event', () => {
      describe('when initialization succeeds', () => {
        beforeEach(async () => {
          getProductAnalyticsSettingsMock.mockResolvedValue(
            getProductAnalyticsProjectSettingsResponse(),
          );
          createWrapper();
          await waitForPromises();
          findComponent().vm.$emit('confirm', loadingStateSvgPath);
          return waitForPromises();
        });

        it('should emit `initialized`', () => {
          expect(wrapper.emitted('initialized')).toStrictEqual([[]]);
        });

        it('should show instance loading state', () => {
          expect(findGlEmptyState().props()).toMatchObject({
            title: 'Creating your product analytics instance…',
            svgPath: loadingStateSvgPath,
          });
          expect(findInstanceLoadingState().exists()).toBe(true);
        });
      });

      describe('when initialize fails', () => {
        describe.each`
          type       | error                     | apolloMock
          ${'api'}   | ${new Error(apiErrorMsg)} | ${mockCreateInstanceError}
          ${'fatal'} | ${fatalError}             | ${mockCreateInstanceFatalError}
        `('with a $type error', ({ error, apolloMock }) => {
          beforeEach(async () => {
            getProductAnalyticsSettingsMock.mockResolvedValue(
              getProductAnalyticsProjectSettingsResponse(),
            );
            createWrapper(apolloMock);
            await waitForPromises();
            findComponent().vm.$emit('confirm');
            return waitForPromises();
          });

          it('does not render the instance loading state', () => {
            expect(findInstanceLoadingState().exists()).toBe(false);
          });

          it('emits the captured error', () => {
            expect(wrapper.emitted('error')).toEqual([[error]]);
          });
        });
      });
    });
  });

  describe('when self-managed provider component emits "open-settings" event', () => {
    beforeEach(async () => {
      getProductAnalyticsSettingsMock.mockResolvedValue(
        getProductAnalyticsProjectSettingsResponse(),
      );
      createWrapper();
      await waitForPromises();

      findSelfManagedProviderCard().vm.$emit('open-settings');
      return waitForPromises();
    });

    it('should redirect the user to settings', () => {
      expect(visitUrl).toHaveBeenCalledWith('/settings/analytics#js-analytics-data-sources', true);
    });
  });
});
