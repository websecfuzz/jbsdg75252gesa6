import { nextTick } from 'vue';
import { GlSprintf, GlLink } from '@gitlab/ui';

import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import SelfManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/self_managed_provider_card.vue';
import ProviderSettingsPreview from 'ee/product_analytics/onboarding/components/providers/provider_settings_preview.vue';
import ClearProjectSettingsModal from 'ee/product_analytics/onboarding/components/providers/clear_project_settings_modal.vue';
import ProviderSettingsForm from 'ee/product_analytics/onboarding/components/providers/provider_settings_form.vue';
import {
  getEmptyProjectLevelAnalyticsProviderSettings,
  getPartialProjectLevelAnalyticsProviderSettings,
  getProjectLevelAnalyticsProviderSettings,
} from '../../../mock_data';

describe('SelfManagedProviderCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findProviderSettingsPreview = () => wrapper.findComponent(ProviderSettingsPreview);
  const findConnectSelfManagedProviderBtn = () =>
    wrapper.findByTestId('connect-your-own-provider-btn');
  const findUseInstanceConfigurationCheckbox = () =>
    wrapper.findByTestId('use-instance-configuration-checkbox');
  const findLink = () => wrapper.findComponent(GlLink);
  const findClearSettingsModal = () => wrapper.findComponent(ClearProjectSettingsModal);
  const findEditSettingsModal = () => wrapper.findByTestId('edit-project-level-settings-modal');
  const findProviderSettingsForm = () => wrapper.findComponent(ProviderSettingsForm);

  const createWrapper = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(SelfManagedProviderCard, {
      propsData: {
        projectSettings: getProjectLevelAnalyticsProviderSettings(),
        ...props,
      },
      provide: {
        isInstanceConfiguredWithSelfManagedAnalyticsProvider: true,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const initProvider = () => {
    findConnectSelfManagedProviderBtn().vm.$emit('click');
    return waitForPromises();
  };

  const checkUseInstanceConfiguration = (checked) => {
    findUseInstanceConfigurationCheckbox().vm.$emit('input', checked);
  };

  const itShouldUseEditSettingsModal = () => {
    describe('when clicking setup', () => {
      beforeEach(() => initProvider());

      it('should show the settings modal', () => {
        expect(findEditSettingsModal().props('visible')).toBe(true);
        expect(findEditSettingsModal().props('title')).toBe('Edit project provider settings');
      });

      it('should hide the modal when it is closed externally', async () => {
        findEditSettingsModal().vm.$emit('change', false);
        await nextTick();

        expect(findEditSettingsModal().props('visible')).toBe(false);
      });

      it('should hide the modal when settings form emits "canceled"', async () => {
        findProviderSettingsForm().vm.$emit('canceled');
        await nextTick();

        expect(findEditSettingsModal().props('visible')).toBe(false);
      });

      it('should select the provider when the settings form emits "saved"', async () => {
        await wrapper.setProps({
          projectSettings: getProjectLevelAnalyticsProviderSettings(),
        });
        findProviderSettingsForm().vm.$emit('saved');
        await nextTick();

        expect(findEditSettingsModal().props('visible')).toBe(false);
        expect(wrapper.emitted('confirm')).toHaveLength(1);
        expect(wrapper.emitted('confirm').at(0)).toStrictEqual(['file-mock']);
      });
    });
  };

  const itShouldUseClearSettingsModal = () => {
    it('should show the clear settings modal', async () => {
      await initProvider();

      const modal = findClearSettingsModal();
      expect(modal.props('visible')).toBe(true);
      expect(modal.text()).toContain(
        'This project has analytics provider settings configured. If you continue, the settings for projects will be reset so that provider settings for the instance can be used.',
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
  };

  describe('default behaviour', () => {
    beforeEach(() => createWrapper());

    it('should render a title and description', () => {
      expect(wrapper.text()).toContain('Self-managed provider');
      expect(wrapper.text()).toContain(
        'Manage your own analytics provider to process, store, and query analytics data.',
      );
    });

    it('should show "Use instance provider settings" checkbox', () => {
      expect(findUseInstanceConfigurationCheckbox().exists()).toBe(true);
    });
  });

  describe('when instance config is a GitLab-managed provider', () => {
    it('should not show "Use instance provider settings" checkbox', () => {
      createWrapper(
        {},
        {
          isInstanceConfiguredWithSelfManagedAnalyticsProvider: false,
        },
      );

      expect(findUseInstanceConfigurationCheckbox().exists()).toBe(false);
    });
  });

  describe('"Use instance provider settings" checkbox default state', () => {
    it.each`
      defaultUseInstanceConfiguration | expectedCheckedState
      ${true}                         | ${'true'}
      ${false}                        | ${undefined}
    `(
      'when state is $defaultUseInstanceConfiguration',
      ({ defaultUseInstanceConfiguration, expectedCheckedState }) => {
        createWrapper(
          {},
          {
            defaultUseInstanceConfiguration,
          },
        );

        expect(findUseInstanceConfigurationCheckbox().attributes('checked')).toBe(
          expectedCheckedState,
        );
      },
    );
  });

  describe('when no project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectSettings: getEmptyProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe('when "Use instance provider settings" is checked', () => {
      beforeEach(() => checkUseInstanceConfiguration(true));

      it('should inform user instance-settings will be used', () => {
        expect(wrapper.text()).toContain(
          'Your instance will be created on the provider configured in your instance settings.',
        );
      });

      it('does not render the link to the public helm-charts project', () => {
        expect(findLink().exists()).toBe(false);
      });

      describe('when selecting provider', () => {
        beforeEach(() => initProvider());

        it('should emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toHaveLength(1);
        });
      });
    });

    describe('when "Use instance provider settings" is unchecked', () => {
      beforeEach(() => checkUseInstanceConfiguration(false));

      it('renders the link to the public helm-charts project', () => {
        expect(findLink().attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/analytics-section/product-analytics/helm-charts',
        );
      });

      itShouldUseEditSettingsModal();
    });
  });

  describe('when some project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectSettings: getPartialProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe('when "Use instance provider settings" is checked', () => {
      beforeEach(() => checkUseInstanceConfiguration(true));

      it('should not show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().exists()).toBe(false);
      });

      itShouldUseClearSettingsModal();
    });

    describe('when "Use instance provider settings" is unchecked', () => {
      beforeEach(() => checkUseInstanceConfiguration(false));

      it('should not show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().exists()).toBe(false);
      });

      itShouldUseEditSettingsModal();
    });
  });

  describe('when all project provider settings are configured', () => {
    beforeEach(() => {
      return createWrapper({
        projectSettings: getProjectLevelAnalyticsProviderSettings(),
      });
    });

    describe('when "Use instance provider settings" is checked', () => {
      beforeEach(() => checkUseInstanceConfiguration(true));

      it('should not show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().exists()).toBe(false);
      });

      itShouldUseClearSettingsModal();
    });

    describe('when "Use instance provider settings" is unchecked', () => {
      beforeEach(() => checkUseInstanceConfiguration(false));

      it('should show summary of existing project-level settings', () => {
        expect(findProviderSettingsPreview().props()).toMatchObject({
          configuratorConnectionString: 'https://configurator.example.com',
          collectorHost: 'https://collector.example.com',
          cubeApiBaseUrl: 'https://cubejs.example.com',
          cubeApiKey: 'abc-123',
        });
      });

      describe('when selecting provider', () => {
        beforeEach(() => initProvider());

        it('should emit "confirm" event', () => {
          expect(wrapper.emitted('confirm')).toEqual([['file-mock']]);
        });
      });
    });
  });
});
