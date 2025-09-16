import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { updateGroupSettings } from 'ee/api/groups_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import DuoWorkflowSettingsForm from 'ee/ai/settings/components/duo_workflow_settings_form.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

jest.mock('ee/api/groups_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

jest.mock('ee/ai/settings/components/early_access_program_banner.vue', () => ({
  name: 'EarlyAccessProgramBanner',
  render: (h) => h('early-access-program-banner'),
}));

let wrapper;

const createComponent = ({ props = {}, provide = {} } = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      redirectPath: '/groups/test-group',
      updateId: '100',
      ...props,
    },
    provide: {
      showEarlyAccessBanner: false,
      onGeneralSettingsPage: false,
      duoWorkflowAvailable: true,
      duoWorkflowMcpEnabled: false,
      ...provide,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findEarlyAccessBanner = () => wrapper.findComponent({ name: 'EarlyAccessProgramBanner' });
const findDuoWorkflowSettingsForm = () => wrapper.findComponent(DuoWorkflowSettingsForm);

describe('AiGroupSettings', () => {
  beforeEach(() => {
    createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders DuoWorkflowSettingsForm component when duoWorkflowAvailable is true', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(true);
    });

    it('does not render DuoWorkflowSettingsForm component when duoWorkflowAvailable is false', () => {
      createComponent({ provide: { duoWorkflowAvailable: false } });
      expect(findDuoWorkflowSettingsForm().exists()).toBe(false);
    });

    it('passes correct props to DuoWorkflowSettingsForm when rendered', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(false);
    });

    it('passes hasFormChanged prop to AiCommonSettings', () => {
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('when showEarlyAccessBanner setting is set', () => {
    it('does not render the banner when the cookie is missing', () => {
      expect(findEarlyAccessBanner().exists()).toBe(false);
    });

    it('is true it renders EarlyAccessProgramBanner', async () => {
      createComponent({ provide: { showEarlyAccessBanner: true } });
      await nextTick();
      await nextTick();
      expect(findEarlyAccessBanner().exists()).toBe(true);
    });
  });

  describe('data initialization', () => {
    it('initializes duoWorkflowMcp from injected value', () => {
      createComponent({ provide: { duoWorkflowMcpEnabled: true } });
      expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(true);
    });
  });

  describe('computed properties', () => {
    describe('hasFormChanged', () => {
      it('returns false when duoWorkflowMcp matches injected value', () => {
        createComponent({ provide: { duoWorkflowMcpEnabled: false } });
        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
      });

      it('returns true when duoWorkflowMcp differs from injected value', async () => {
        createComponent({ provide: { duoWorkflowMcpEnabled: false } });
        findDuoWorkflowSettingsForm().vm.$emit('change', true);

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });
    });
  });

  describe('methods', () => {
    describe('onDuoWorkflowFormChanged', () => {
      it('updates duoWorkflowMcp value', async () => {
        findDuoWorkflowSettingsForm().vm.$emit('change', true);

        await nextTick();

        expect(findDuoWorkflowSettingsForm().props('isMcpEnabled')).toBe(true);
        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateGroupSettings with correct parameters', async () => {
      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
        duoCoreFeaturesEnabled: true,
        promptCacheEnabled: true,
      });
      expect(updateGroupSettings).toHaveBeenCalledTimes(1);
      expect(updateGroupSettings).toHaveBeenCalledWith('100', {
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experiment_features_enabled: true,
        duo_core_features_enabled: true,
        model_prompt_cache_enabled: true,
        ai_settings_attributes: {
          duo_workflow_mcp_enabled: false,
        },
      });
    });

    it('includes updated duoWorkflowMcp value in API call', async () => {
      updateGroupSettings.mockResolvedValue({});
      wrapper.vm.onDuoWorkflowFormChanged(true);
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
        duoCoreFeaturesEnabled: true,
        promptCacheEnabled: true,
      });
      expect(updateGroupSettings).toHaveBeenCalledWith(
        '100',
        expect.objectContaining({
          ai_settings_attributes: {
            duo_workflow_mcp_enabled: true,
          },
        }),
      );
    });

    it('shows success message on successful update', async () => {
      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: false,
      });
      await waitForPromises();
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({
            id: 'organization-group-successfully-updated',
            message: 'Group was successfully updated.',
            variant: VARIANT_INFO,
          }),
        ]),
      );
    });

    it('shows error message on failed update', async () => {
      const error = new Error('API error');
      updateGroupSettings.mockRejectedValue(error);
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: true,
      });
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message:
            'An error occurred while retrieving your settings. Reload the page to try again.',
          captureError: true,
          error,
        }),
      );
    });

    describe('when on general settings section', () => {
      it('does not update duo core setting', async () => {
        createComponent({ provide: { onGeneralSettingsPage: true } });

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
        });
        expect(updateGroupSettings).toHaveBeenCalledTimes(1);
        expect(updateGroupSettings).toHaveBeenCalledWith('100', {
          duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experiment_features_enabled: false,
          model_prompt_cache_enabled: true,
          ai_settings_attributes: {
            duo_workflow_mcp_enabled: false,
          },
        });
        expect(updateGroupSettings).not.toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            duo_core_features_enabled: expect.anything(),
          }),
        );
      });
    });
  });
});
