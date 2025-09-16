import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import { GlLink, GlModal, GlSprintf } from '@gitlab/ui';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import ClearProjectSettingsModal from 'ee/product_analytics/onboarding/components/providers/clear_project_settings_modal.vue';
import productAnalyticsProjectSettingsUpdate from 'ee/product_analytics/graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import getProductAnalyticsProjectSettings from 'ee/product_analytics/graphql/queries/get_product_analytics_project_settings.query.graphql';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
  getProductAnalyticsProjectSettingsUpdateResponse,
  TEST_PROJECT_FULL_PATH,
  TEST_PROJECT_ID,
} from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ClearProjectSettingsModal', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let mockApollo;

  const mockGetProjectSettings = jest.fn();
  const mockMutate = jest.fn();

  const findModal = () => wrapper.findComponent(GlModal);
  const findModalError = () => wrapper.findByTestId('modal-error');

  const createWrapper = (props = {}, provide = {}) => {
    mockApollo = createMockApollo([
      [getProductAnalyticsProjectSettings, mockGetProjectSettings],
      [productAnalyticsProjectSettingsUpdate, mockMutate],
    ]);

    wrapper = shallowMountExtended(ClearProjectSettingsModal, {
      apolloProvider: mockApollo,
      propsData: {
        visible: true,
        ...props,
      },
      provide: {
        analyticsSettingsPath: `/${TEST_PROJECT_FULL_PATH}/-/settings/analytics`,
        namespaceFullPath: TEST_PROJECT_FULL_PATH,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const confirmRemoveSetting = async () => {
    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await nextTick();
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render modal', () => {
      expect(findModal().props('visible')).toBe(true);
    });
  });

  describe('when cancelling', () => {
    beforeEach(() => {
      createWrapper();
      findModal().vm.$emit('canceled');
      return nextTick();
    });

    it('should emit "hide" event', () => {
      expect(wrapper.emitted('hide')).toHaveLength(1);
    });

    it('should not modify project settings', () => {
      expect(mockMutate).not.toHaveBeenCalled();
    });
  });

  describe('when confirming', () => {
    let mockWriteQuery;
    beforeEach(() => {
      mockWriteQuery = jest.fn();
      createWrapper();
      mockApollo.clients.defaultClient.cache.readQuery = jest.fn().mockReturnValue({
        project: {
          id: TEST_PROJECT_ID,
          productAnalyticsSettings: getPartialProjectLevelAnalyticsProviderSettings(),
        },
      });
      mockApollo.clients.defaultClient.cache.writeQuery = mockWriteQuery;
    });

    it('should set loading state', async () => {
      mockMutate.mockReturnValue(new Promise(() => {}));
      await confirmRemoveSetting();

      const modal = findModal();
      expect(modal.props('actionPrimary').attributes.loading).toBe(true);
      expect(modal.props('actionCancel').attributes.disabled).toBe(true);
    });

    it('should clear settings', async () => {
      mockMutate.mockResolvedValue(getProductAnalyticsProjectSettingsUpdateResponse());
      await confirmRemoveSetting();

      expect(mockMutate).toHaveBeenCalledWith({
        fullPath: 'group-1/project-1',
        productAnalyticsConfiguratorConnectionString: null,
        productAnalyticsDataCollectorHost: null,
        cubeApiBaseUrl: null,
        cubeApiKey: null,
      });
    });

    it('updates the apollo cache after a successful mutation', async () => {
      mockMutate.mockResolvedValue(getProductAnalyticsProjectSettingsUpdateResponse());
      await confirmRemoveSetting();
      await waitForPromises();

      expect(mockWriteQuery).toHaveBeenCalledTimes(1);
      expect(mockWriteQuery).toHaveBeenCalledWith({
        query: getProductAnalyticsProjectSettings,
        variables: { projectPath: TEST_PROJECT_FULL_PATH },
        data: {
          project: {
            id: TEST_PROJECT_ID,
            productAnalyticsSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
          },
        },
      });
    });

    describe('when the mutation fails', () => {
      describe('with a network level error', () => {
        const error = new Error('uh oh!');
        beforeEach(async () => {
          mockMutate.mockRejectedValue(error);
          await confirmRemoveSetting();
          return waitForPromises();
        });

        it('should display an error', () => {
          expect(findModalError().text()).toContain(
            'Failed to clear project-level settings. Please try again or clear them manually.',
          );
          expect(findModalError().findComponent(GlLink).attributes('href')).toBe(
            '/group-1/project-1/-/settings/analytics',
          );
        });

        it('should not show loading state', () => {
          const modal = findModal();
          expect(modal.props('actionPrimary').attributes.loading).toBe(false);
          expect(modal.props('actionCancel').attributes.disabled).toBe(false);
        });

        it('should log to Sentry', () => {
          expect(Sentry.captureException).toHaveBeenCalledWith(error);
        });
      });

      describe('with a response error', () => {
        beforeEach(async () => {
          mockMutate.mockResolvedValue(
            getProductAnalyticsProjectSettingsUpdateResponse(
              getEmptyProjectLevelAnalyticsProviderSettings(),
              [new Error('uh oh!')],
            ),
          );
          await confirmRemoveSetting();
          return waitForPromises();
        });

        it('should display an error', () => {
          expect(findModalError().text()).toContain(
            'Failed to clear project-level settings. Please try again or clear them manually.',
          );
          expect(findModalError().findComponent(GlLink).attributes('href')).toBe(
            '/group-1/project-1/-/settings/analytics',
          );
        });

        it('should not show loading state', () => {
          const modal = findModal();
          expect(modal.props('actionPrimary').attributes.loading).toBe(false);
          expect(modal.props('actionCancel').attributes.disabled).toBe(false);
        });

        it('should not log to Sentry', () => {
          expect(Sentry.captureException).not.toHaveBeenCalled();
        });
      });
    });

    describe('when the settings have successfully cleared', () => {
      beforeEach(async () => {
        mockMutate.mockResolvedValue(getProductAnalyticsProjectSettingsUpdateResponse());
        await confirmRemoveSetting();
        await wrapper.setProps({
          projectSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
        });
        return waitForPromises();
      });

      it('should emit "hide" event', () => {
        expect(wrapper.emitted('hide')).toHaveLength(1);
      });

      it('should emit "cleared" event', () => {
        expect(wrapper.emitted('cleared')).toHaveLength(1);
      });
    });
  });
});
