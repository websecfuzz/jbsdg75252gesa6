import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import DuoConfigurationSettingsInfoCard from 'ee/ai/settings/components/duo_configuration_settings_info_card.vue';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';
import { DUO_ENTERPRISE } from 'ee/constants/duo';

jest.mock('~/lib/utils/url_utility');

describe('DuoConfigurationSettingsInfoCard', () => {
  let wrapper;

  const createComponent = (
    {
      aiGatewayUrl = 'http://0.0.0.0:5052',
      canManageSelfHostedModels = false,
      duoConfigurationPath = '/gitlab_duo/configuration',
      isSaaS = false,
      isStandalonePage = false,
      duoAvailability = AVAILABILITY_OPTIONS.DEFAULT_ON,
      directCodeSuggestionsEnabled = true,
      experimentFeaturesEnabled = true,
      betaSelfHostedModelsEnabled = true,
      areExperimentSettingsAllowed = true,
      areDuoCoreFeaturesEnabled = true,
    } = {},
    props = {},
  ) => {
    wrapper = shallowMountExtended(DuoConfigurationSettingsInfoCard, {
      provide: {
        aiGatewayUrl,
        canManageSelfHostedModels,
        duoConfigurationPath,
        isSaaS,
        isStandalonePage,
        duoAvailability,
        directCodeSuggestionsEnabled,
        experimentFeaturesEnabled,
        betaSelfHostedModelsEnabled,
        areExperimentSettingsAllowed,
        areDuoCoreFeaturesEnabled,
      },
      propsData: {
        activeDuoTier: DUO_ENTERPRISE,
        ...props,
      },
    });
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findConfigurationButton = () => wrapper.findComponent(GlButton);
  const findDuoConfigurationRows = () => wrapper.findAllComponents(DuoConfigurationSettingsRow);
  const findAllDuoConfigurationRowTitleProps = () =>
    findDuoConfigurationRows().wrappers.map((row) =>
      row.props('duoConfigurationSettingsRowTypeTitle'),
    );
  const findDuoConfigurationRowTitlePropByRowIdx = (idx) =>
    findDuoConfigurationRows().at(idx).props('duoConfigurationSettingsRowTypeTitle');
  const findDuoConfigurationSettingsInfo = () =>
    wrapper.findByTestId('duo-configuration-settings-info');
  const findConfigurationStatus = () => wrapper.findByTestId('configuration-status');
  const findDuoCoreConfigValue = () => findDuoConfigurationRows().at(0).props('configValue');

  describe('on component loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the GlCard component', () => {
      expect(findCard().exists()).toBe(true);
    });

    it('renders the title correctly', () => {
      expect(findDuoConfigurationSettingsInfo().text()).toBe('GitLab Duo Enterprise');
    });

    it('renders the configuration button with correct href', () => {
      expect(findConfigurationButton().exists()).toBe(true);
      expect(findConfigurationButton().attributes('href')).toBe('/gitlab_duo/configuration');
      expect(findConfigurationButton().text()).toBe('Change configuration');
    });
  });

  describe('availability status', () => {
    it.each([
      [AVAILABILITY_OPTIONS.DEFAULT_ON, 'On by default'],
      [AVAILABILITY_OPTIONS.DEFAULT_OFF, 'Off by default'],
      [AVAILABILITY_OPTIONS.NEVER_ON, 'Always off'],
    ])('displays correct status for %s', (status, expected) => {
      createComponent({ duoAvailability: status });
      expect(findConfigurationStatus().text()).toBe(expected);
    });
  });

  describe('DuoConfigurationSettingsRow rendering', () => {
    describe('for self-managed instance', () => {
      it('renders the correct rows', () => {
        createComponent({ isSaaS: false });

        expect(findDuoConfigurationRows()).toHaveLength(3);
        expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
          'GitLab Duo Core available to all users',
        );
        expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
        expect(findDuoConfigurationRowTitlePropByRowIdx(2)).toBe('Direct connections');
      });

      describe('with self-hosted Duo enabled', () => {
        it('renders the correct rows', () => {
          createComponent({ isSaaS: false, canManageSelfHostedModels: true });

          expect(findDuoConfigurationRows()).toHaveLength(6);
          expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
            'GitLab Duo Core available to all users',
          );
          expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
          expect(findDuoConfigurationRowTitlePropByRowIdx(2)).toBe('Direct connections');
          expect(findDuoConfigurationRowTitlePropByRowIdx(3)).toBe(
            'Self-hosted beta models and features',
          );
          expect(findDuoConfigurationRowTitlePropByRowIdx(4)).toBe('AI logs');
          expect(findDuoConfigurationRowTitlePropByRowIdx(5)).toBe('Local AI gateway URL');
        });

        describe('when AI gateway URL is not set', () => {
          it('does not render the config row', () => {
            createComponent({ isSaaS: false, canManageSelfHostedModels: true, aiGatewayUrl: null });

            expect(findDuoConfigurationRows()).toHaveLength(5);
            expect(findAllDuoConfigurationRowTitleProps()).not.toContain('Local AI gateway URL');
          });
        });
      });
    });

    it('renders fewer rows for SaaS instance', () => {
      createComponent({ isSaaS: true });

      expect(findDuoConfigurationRows()).toHaveLength(2);
      expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe(
        'GitLab Duo Core available to all users',
      );
      expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Experiment and beta features');
    });

    it('passes correct props to configuration rows', () => {
      createComponent();
      expect(findDuoConfigurationRows().at(0).props('configValue')).toBe(true);
      expect(findDuoConfigurationRows().at(1).props('configValue')).toBe(true);
      expect(findDuoConfigurationRows().at(2).props('configValue')).toBe(true);
    });

    describe('when Duo Core features are enabled and availability is on', () => {
      it('sets config value for Duo Core to true', () => {
        createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          areDuoCoreFeaturesEnabled: true,
        });
        expect(findDuoCoreConfigValue()).toBe(true);
      });
    });

    describe('when Duo Core features are enabled and availability is off', () => {
      it('sets config value for Duo Core to false', () => {
        createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON,
          areDuoCoreFeaturesEnabled: false,
        });
        expect(findDuoCoreConfigValue()).toBe(false);
      });
    });

    describe('when Duo Core features are disabled and availability is on', () => {
      it('sets config value for Duo Core to false', () => {
        createComponent({
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          areDuoCoreFeaturesEnabled: false,
        });
        expect(findDuoCoreConfigValue()).toBe(false);
      });
    });
  });
});
