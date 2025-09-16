import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import ProviderSettingsForm from 'ee/product_analytics/onboarding/components/providers/provider_settings_form.vue';
import productAnalyticsProjectSettingsUpdate from 'ee/product_analytics/graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import getProductAnalyticsProjectSettings from 'ee/product_analytics/graphql/queries/get_product_analytics_project_settings.query.graphql';
import {
  getPartialProjectLevelAnalyticsProviderSettings,
  getProductAnalyticsProjectSettingsUpdateResponse,
  getProjectLevelAnalyticsProviderSettings,
  TEST_PROJECT_FULL_PATH,
  TEST_PROJECT_ID,
} from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('ProviderSettingsForm', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let mockApollo;
  let validProjectSettings;

  const mockGetProjectSettings = jest.fn();
  const mockMutate = jest.fn();

  const findConfiguratorConnectionStringInput = () =>
    wrapper.findByTestId('configurator-connection-string-input');
  const findCollectorHostInput = () => wrapper.findByTestId('collector-host-input');
  const findCollectorHostFormGroup = () => wrapper.findByTestId('collector-host-form-group');
  const findCubeApiUrlInput = () => wrapper.findByTestId('cube-api-url-input');
  const findCubeApiUrlFormGroup = () => wrapper.findByTestId('cube-api-url-form-group');
  const findCubeApiKeyInput = () => wrapper.findByTestId('cube-api-key-input');
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findModalError = () =>
    wrapper.findByTestId('clear-project-level-settings-confirmation-modal-error');

  const createWrapper = (props = {}, provide = {}) => {
    validProjectSettings = getProjectLevelAnalyticsProviderSettings();
    mockApollo = createMockApollo([
      [getProductAnalyticsProjectSettings, mockGetProjectSettings],
      [productAnalyticsProjectSettingsUpdate, mockMutate],
    ]);

    wrapper = shallowMountExtended(ProviderSettingsForm, {
      apolloProvider: mockApollo,
      propsData: {
        projectSettings: getProjectLevelAnalyticsProviderSettings(),
        ...props,
      },
      provide: {
        namespaceFullPath: TEST_PROJECT_FULL_PATH,
        ...provide,
      },
    });
  };

  const submitForm = async () => {
    findSubmitButton().vm.$emit('click');
    await nextTick();
  };

  const expectLoadingState = (isLoading) => {
    expect(findSubmitButton().props('loading')).toBe(isLoading);

    expect(findSubmitButton().props('disabled')).toBe(isLoading);
    expect(findCancelButton().props('disabled')).toBe(isLoading);

    const expectedAttributeState = isLoading ? 'true' : undefined;
    expect(findConfiguratorConnectionStringInput().attributes().disabled).toBe(
      expectedAttributeState,
    );
    expect(findCollectorHostInput().attributes().disabled).toBe(expectedAttributeState);
    expect(findCubeApiUrlInput().attributes().disabled).toBe(expectedAttributeState);
    expect(findCubeApiKeyInput().attributes().disabled).toBe(expectedAttributeState);
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render form fields', () => {
      expect(findConfiguratorConnectionStringInput().exists()).toBe(true);
      expect(findCollectorHostInput().exists()).toBe(true);
      expect(findCubeApiUrlInput().exists()).toBe(true);
      expect(findCubeApiKeyInput().exists()).toBe(true);
    });

    it('should populate form with existing values', () => {
      expect(findConfiguratorConnectionStringInput().props('value')).toBe(
        'https://configurator.example.com',
      );
      expect(findCollectorHostInput().attributes('value')).toBe('https://collector.example.com');
      expect(findCubeApiUrlInput().attributes('value')).toBe('https://cubejs.example.com');
      expect(findCubeApiKeyInput().props('value')).toBe('abc-123');
    });

    it('should mask existing sensitive values by default', () => {
      expect(findConfiguratorConnectionStringInput().props('initialVisibility')).toBe(false);
      expect(findCubeApiKeyInput().props('initialVisibility')).toBe(false);
    });
  });

  describe('when cancelling', () => {
    beforeEach(() => {
      createWrapper();
      findCancelButton().vm.$emit('click');
      return nextTick();
    });

    it('should emit "canceled" event', () => {
      expect(wrapper.emitted('canceled')).toHaveLength(1);
    });

    it('should not modify project settings', () => {
      expect(mockMutate).not.toHaveBeenCalled();
    });
  });

  describe('with validation issues', () => {
    beforeEach(async () => {
      createWrapper();
      findConfiguratorConnectionStringInput().vm.$emit('input', 'not-a-valid-url');
      findCollectorHostInput().vm.$emit('input', 'not-a-valid-url');
      findCubeApiUrlInput().vm.$emit('input', '');
      findCubeApiKeyInput().vm.$emit('input', '');

      await submitForm();
      await nextTick();
    });

    it('should set expected validation messages', () => {
      expect(findConfiguratorConnectionStringInput().attributes('invalid-feedback')).toBe(
        'Enter a valid URL',
      );
      expect(findCollectorHostFormGroup().attributes('invalid-feedback')).toBe('Enter a valid URL');
      expect(findCubeApiUrlFormGroup().attributes('invalid-feedback')).toBe(
        'This field is required',
      );
      expect(findCubeApiKeyInput().attributes('invalid-feedback')).toBe('This field is required');
    });

    it('should not modify project settings', () => {
      expect(mockMutate).not.toHaveBeenCalled();
    });
  });

  describe('with valid values', () => {
    let mockWriteQuery;

    beforeEach(() => {
      mockWriteQuery = jest.fn();
      createWrapper();
      mockApollo.clients.defaultClient.cache.writeQuery = mockWriteQuery;
      mockApollo.clients.defaultClient.cache.readQuery = jest.fn().mockReturnValue({
        project: {
          id: TEST_PROJECT_ID,
          productAnalyticsSettings: getPartialProjectLevelAnalyticsProviderSettings(),
        },
      });
    });

    it('should not show validation errors', () => {
      expect(
        findConfiguratorConnectionStringInput().attributes('invalid-feedback'),
      ).toBeUndefined();
      expect(findCollectorHostFormGroup().attributes('invalid-feedback')).toBeUndefined();
      expect(findCubeApiUrlFormGroup().attributes('invalid-feedback')).toBeUndefined();
      expect(findCubeApiKeyInput().attributes('invalid-feedback')).toBeUndefined();
    });

    it('should set loading state', async () => {
      mockMutate.mockReturnValue(new Promise(() => {}));
      await submitForm();

      expectLoadingState(true);
    });

    it('should save the settings', async () => {
      mockMutate.mockResolvedValue(
        getProductAnalyticsProjectSettingsUpdateResponse(validProjectSettings),
      );
      await submitForm();

      expect(mockMutate).toHaveBeenCalledWith({
        fullPath: 'group-1/project-1',
        productAnalyticsConfiguratorConnectionString: 'https://configurator.example.com',
        productAnalyticsDataCollectorHost: 'https://collector.example.com',
        cubeApiBaseUrl: 'https://cubejs.example.com',
        cubeApiKey: 'abc-123',
      });
    });

    it('updates the apollo cache after a successful mutation', async () => {
      mockMutate.mockResolvedValue(
        getProductAnalyticsProjectSettingsUpdateResponse(validProjectSettings),
      );
      await submitForm();
      await waitForPromises();

      expect(mockWriteQuery).toHaveBeenCalledTimes(1);
      expect(mockWriteQuery).toHaveBeenCalledWith({
        query: getProductAnalyticsProjectSettings,
        variables: { projectPath: TEST_PROJECT_FULL_PATH },
        data: {
          project: {
            id: TEST_PROJECT_ID,
            productAnalyticsSettings: validProjectSettings,
          },
        },
      });
    });

    describe('when the mutation fails', () => {
      describe('with a network level error', () => {
        const error = new Error('uh oh!');
        beforeEach(async () => {
          mockMutate.mockRejectedValue(error);
          await submitForm();
          return waitForPromises();
        });

        it('should display an error', () => {
          expect(findModalError().text()).toContain(
            'Failed to update project-level settings. Please try again.',
          );
        });

        it('should not show loading state', () => {
          expectLoadingState(false);
        });

        it('should log to Sentry', () => {
          expect(Sentry.captureException).toHaveBeenCalledWith(error);
        });
      });

      describe('with a response error', () => {
        beforeEach(async () => {
          mockMutate.mockResolvedValue(
            getProductAnalyticsProjectSettingsUpdateResponse(validProjectSettings, [
              new Error('uh oh!'),
            ]),
          );
          await submitForm();
          return waitForPromises();
        });

        it('should display an error', () => {
          expect(findModalError().text()).toContain(
            'Failed to update project-level settings. Please try again.',
          );
        });

        it('should not show loading state', () => {
          expectLoadingState(false);
        });

        it('should not log to Sentry', () => {
          expect(Sentry.captureException).not.toHaveBeenCalled();
        });
      });
    });

    describe('when the mutation succeeds', () => {
      beforeEach(async () => {
        mockMutate.mockResolvedValue(
          getProductAnalyticsProjectSettingsUpdateResponse(validProjectSettings),
        );
        await submitForm();
        return waitForPromises();
      });

      it('should emit "saved" event', () => {
        expect(wrapper.emitted('saved')).toHaveLength(1);
      });
    });
  });
});
