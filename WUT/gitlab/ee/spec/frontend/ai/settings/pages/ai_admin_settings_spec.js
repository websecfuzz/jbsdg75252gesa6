import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import createMockApollo from 'helpers/mock_apollo_helper';
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGtewayUrlInputForm from 'ee/ai/settings/components/ai_gateway_url_input_form.vue';
import CodeSuggestionsConnectionForm from 'ee/ai/settings/components/code_suggestions_connection_form.vue';
import AiModelsForm from 'ee/ai/settings/components/ai_models_form.vue';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import updateAiSettingsMutation from 'ee/ai/graphql/update_ai_settings.mutation.graphql';
import DuoExpandedLoggingForm from 'ee/ai/settings/components/duo_expanded_logging_form.vue';
import DuoChatHistoryExpirationForm from 'ee/ai/settings/components/duo_chat_history_expiration.vue';

jest.mock('~/rest_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

Vue.use(VueApollo);

let wrapper;
let axiosMock;

const aiGatewayUrl = 'http://localhost:5052';
const toggleBetaModelsPath = '/admin/ai/duo_self_hosted/terms_and_condition';
const updateAiSettingsSuccessHandler = jest.fn().mockResolvedValue({
  data: {
    duoSettings: {
      aiGatewayUrl: 'http://new-aigw-url.com',
      errors: [],
    },
  },
});

const createComponent = async ({
  props = {},
  provide = {},
  apolloHandlers = [[updateAiSettingsMutation, updateAiSettingsSuccessHandler]],
} = {}) => {
  const mockApollo = createMockApollo([...apolloHandlers]);

  wrapper = shallowMount(AiAdminSettings, {
    apolloProvider: mockApollo,
    propsData: {
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      redirectPath: '/admin/application_settings',
      duoProVisible: true,
      ...props,
    },
    provide: {
      disabledDirectConnectionMethod: false,
      betaSelfHostedModelsEnabled: false,
      canManageSelfHostedModels: true,
      enabledExpandedLogging: false,
      toggleBetaModelsPath,
      aiGatewayUrl,
      duoChatExpirationDays: 30,
      duoChatExpirationColumn: 'last_updated_at',
      duoCoreFeaturesEnabled: false,
      ...provide,
    },
  });

  await waitForPromises();
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findCodeSuggestionsConnectionForm = () =>
  wrapper.findComponent(CodeSuggestionsConnectionForm);
const findAiModelsForm = () => wrapper.findComponent(AiModelsForm);
const findAiGatewayUrlInputForm = () => wrapper.findComponent(AiGtewayUrlInputForm);
const findDuoExpandedLoggingForm = () => wrapper.findComponent(DuoExpandedLoggingForm);
const findDuoChatHistoryExpirationForm = () => wrapper.findComponent(DuoChatHistoryExpirationForm);

describe('AiAdminSettings', () => {
  beforeEach(async () => {
    await createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('passes correct props to AiCommonSettings', () => {
      expect(findAiCommonSettings().props()).toEqual({
        hasParentFormChanged: false,
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateApplicationSettings with correct params', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: true,
      });
      expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        instance_level_ai_beta_features_enabled: false,
        model_prompt_cache_enabled: true,
        disabled_direct_code_suggestions: false,
        enabled_expanded_logging: false,
        duo_chat_expiration_days: 30,
        duo_chat_expiration_column: 'last_updated_at',
      });
    });

    describe('when AI settings have changed', () => {
      describe('with canManageSelfHostedModels true', () => {
        it('updates aiGatewayUrl', async () => {
          const newAiGatewayUrl = 'http://new-ai-gateway-url.com';

          await findAiGatewayUrlInputForm().vm.$emit('change', newAiGatewayUrl);

          await findAiCommonSettings().vm.$emit('submit', { duoCoreFeaturesEnabled: false });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://new-ai-gateway-url.com',
              duoCoreFeaturesEnabled: false,
            },
          });
        });
      });

      describe('with canManageSelfHostedModels false', () => {
        beforeEach(() => {
          createComponent({ provide: { canManageSelfHostedModels: false } });
        });

        it('does not update aiGatewayUrl', async () => {
          await findAiCommonSettings().vm.$emit('submit', { duoCoreFeaturesEnabled: true });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              duoCoreFeaturesEnabled: true,
            },
          });
        });
      });

      it('updates duoCoreFeaturesEnabled', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoCoreFeaturesEnabled: true,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            aiGatewayUrl: 'http://localhost:5052',
            duoCoreFeaturesEnabled: true,
          },
        });
      });
    });

    describe('when the beta models setting has changed', () => {
      beforeEach(() => {
        axiosMock = new MockAdapter(axios);
        jest.spyOn(axios, 'post');

        createComponent({ provide: { betaSelfHostedModelsEnabled: true } });
      });

      afterEach(() => {
        axiosMock.restore();
      });

      it('triggers a post request to persist the change', async () => {
        await findAiModelsForm().vm.$emit('change', false);
        await findAiCommonSettings().vm.$emit('submit', { duoCoreFeaturesEnabled: false });
        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(toggleBetaModelsPath);
      });
    });

    it('shows success message on successful update', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
      });
      await waitForPromises();
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Application settings saved successfully.',
          }),
        ]),
      );
    });

    it('shows error message on failed update', async () => {
      const error = new Error('Update failed');
      updateApplicationSettings.mockRejectedValue(error);

      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
      });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: error.message,
          error,
        }),
      );
    });
  });

  describe('when duoProVisible', () => {
    it('is availabile it does display the connection form', () => {
      createComponent({ props: { duoProVisible: true } });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(true);
    });

    it('is not availabile it does not display the connection form', () => {
      createComponent({ props: { duoProVisible: false } });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(false);
    });
  });

  describe('canManageSelfHostedModels', () => {
    describe('when canManageSelfHostedModels is true', () => {
      it('renders AI models form', () => {
        expect(findAiModelsForm().exists()).toBe(true);
      });

      it('renders AI gateway URL input form', () => {
        expect(findAiGatewayUrlInputForm().exists()).toBe(true);
      });

      it('renders the expanded logging form', () => {
        expect(findDuoExpandedLoggingForm().exists()).toBe(true);
      });
    });

    describe('when canManageSelfHostedModels is false', () => {
      beforeEach(() => {
        createComponent({ provide: { canManageSelfHostedModels: false } });
      });

      it('does not render self-hosted models form', () => {
        expect(findAiModelsForm().exists()).toBe(false);
      });

      it('does not render AI gateway URL input form', () => {
        expect(findAiGatewayUrlInputForm().exists()).toBe(false);
      });

      it('does not render the expanded logging form', () => {
        expect(findDuoExpandedLoggingForm().exists()).toBe(false);
      });
    });
  });

  describe('onConnectionFormChange', () => {
    beforeEach(async () => {
      await createComponent({ props: { duoProVisible: true } });
    });

    it('sets hasParentFormChanged to true when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', true);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('sets hasParentFormChanged to false when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', false);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('onAiModelsFormChange', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when ai models form changes', async () => {
      await findAiModelsForm().vm.$emit('change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onAiGatewayUrlChange', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when the AI gateway url value changes', async () => {
      await findAiGatewayUrlInputForm().vm.$emit('change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onExpandedLoggingFormChanged', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when Duo expanded logging form changes', async () => {
      await findDuoExpandedLoggingForm().vm.$emit('change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onDuoChatHistoryExpirationFormChanged', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the DuoChatHistoryExpirationForm component', () => {
      expect(findDuoChatHistoryExpirationForm().exists()).toBe(true);
    });

    it('updates chatExpirationDays when days value changes', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-days', 15);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('updates chatExpirationColumn when column value changes', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-column', 'created_at');

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('does not update hasParentFormChanged when the default expiration values are provided', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-days', 30);
      await findDuoChatHistoryExpirationForm().vm.$emit(
        'change-expiration-column',
        'last_updated_at',
      );

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });
});
