import { GlTabs, GlTab } from '@gitlab/ui';
import { nextTick } from 'vue';
import Api from '~/api';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityConfigurationApp from '~/security_configuration/components/app.vue';
import UpgradeBanner from 'ee/security_configuration/components/upgrade_banner.vue';
import VulnerabilityArchives from 'ee/security_configuration/components/vulnerability_archives.vue';
import { securityFeaturesMock, provideMock } from 'jest/security_configuration/mock_data';
import { SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT } from '~/tracking/constants';
import { TAB_VULNERABILITY_MANAGEMENT_INDEX } from '~/security_configuration/constants';
import { REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY } from '~/vue_shared/security_reports/constants';
import FeatureCard from '~/security_configuration/components/feature_card.vue';
import ContainerScanningForRegistryFeatureCard from 'ee_component/security_configuration/components/container_scanning_for_registry_feature_card.vue';
import ApplySecurityLabels from 'ee/security_configuration/security_labels/components/apply_security_labels.vue';
import { stubComponent } from 'helpers/stub_component';

jest.mock('~/api.js');

describe('~/security_configuration/components/app', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createComponent = ({
    props: { shouldShowCallout = true, ...propsData } = {},
    provide = {},
    mountFn = mountExtended,
    stubs,
  } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = mountFn(SecurityConfigurationApp, {
      propsData: {
        augmentedSecurityFeatures: securityFeaturesMock,
        securityTrainingEnabled: true,
        ...propsData,
      },
      provide: {
        ...provideMock,
        vulnerabilityArchiveExportPath: '/some/path',
        userIsProjectAdmin: true,
        ...provide,
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        ...stubs,
      },
    });
  };

  const findVulnerabilityArchives = () => wrapper.findComponent(VulnerabilityArchives);
  const findUpgradeBanner = () => wrapper.findComponent(UpgradeBanner);
  const findTabsComponent = () => wrapper.findComponent(GlTabs);
  const findTabAtIndex = (i) => wrapper.findAllComponents(GlTab).at(i);
  const findFeatureCards = () => wrapper.findAllComponents(FeatureCard);
  const findContainerScanningForRegistry = () =>
    wrapper.findComponent(ContainerScanningForRegistryFeatureCard);

  describe('upgrade banner', () => {
    const makeAvailable = (available) => (feature) => ({ ...feature, available });

    describe('given at least one unavailable feature', () => {
      beforeEach(async () => {
        await createComponent({
          props: {
            augmentedSecurityFeatures: [
              {
                ...securityFeaturesMock[0],
                available: false,
              },
            ],
          },
        });
      });

      it('renders the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(true);
      });

      it('calls the dismiss callback when closing the banner', () => {
        expect(userCalloutDismissSpy).not.toHaveBeenCalled();

        findUpgradeBanner().vm.$emit('close');

        expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('given at least one unavailable feature, but banner is already dismissed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            shouldShowCallout: false,
          },
        });
      });

      it('does not render the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(false);
      });
    });

    describe('given all features are available', () => {
      beforeEach(() => {
        createComponent({
          props: {
            augmentedSecurityFeatures: securityFeaturesMock.map(makeAvailable(true)),
          },
        });
      });

      it('does not render the banner', () => {
        expect(findUpgradeBanner().exists()).toBe(false);
      });
    });
  });

  describe('tab change', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders two tabs', () => {
      expect(findTabAtIndex(0).exists()).toBe(true);
      expect(findTabAtIndex(1).exists()).toBe(true);
    });

    it('tracks "users_visiting_security_configuration_threat_management" when threat management tab is selected', () => {
      findTabsComponent().vm.$emit('input', TAB_VULNERABILITY_MANAGEMENT_INDEX);

      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT,
      );
    });

    it("doesn't track the metric when other tab is selected", () => {
      findTabsComponent().vm.$emit('input', 0);

      expect(Api.trackRedisHllUserEvent).not.toHaveBeenCalled();
    });
  });

  describe('with container scanning for registry', () => {
    beforeEach(() => {
      createComponent({
        props: {
          augmentedSecurityFeatures: [
            {
              type: REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY,
            },
          ],
        },
      });
    });

    it('does not render the feature card component', () => {
      expect(findFeatureCards()).toHaveLength(0);
    });

    it('renders the component', () => {
      expect(findContainerScanningForRegistry().exists()).toBe(true);
      expect(findContainerScanningForRegistry().props('feature')).toEqual({
        type: REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY,
      });
    });
  });

  describe('Vulnerability archives', () => {
    it.each`
      featureFlag
      ${true}
      ${false}
    `('does not render archives if flag is $featureFlag', async ({ featureFlag }) => {
      await createComponent({
        provide: { glFeatures: { vulnerabilityArchival: featureFlag } },
        mountFn: shallowMountExtended,
        stubs: {
          GlTab: stubComponent(GlTab, {
            template: `
              <li>
                <slot name="title"></slot>
                <slot></slot>
              </li>
            `,
          }),
        },
      });

      await nextTick();

      expect(findVulnerabilityArchives().exists()).toBe(featureFlag);
    });
  });

  describe('Security labels tab', () => {
    describe.each`
      securityLabels | securityContextLabels | result
      ${false}       | ${false}              | ${false}
      ${false}       | ${true}               | ${false}
      ${true}        | ${false}              | ${false}
      ${true}        | ${true}               | ${true}
    `(
      'with licensed feature set to $securityLabels and feature flag set to $securityContextLabels',
      ({ securityLabels, securityContextLabels, result }) => {
        beforeEach(async () => {
          window.gon = {
            licensed_features: { securityLabels },
          };

          createComponent({
            provide: { glFeatures: { securityContextLabels } },
            mountFn: shallowMountExtended,
            stubs: {
              GlTab: stubComponent(GlTab, {
                template: `
              <li>
                <slot name="title"></slot>
                <slot></slot>
              </li>
            `,
              }),
            },
          });

          await nextTick();
        });

        it('renders the tab when correctly licensed', () => {
          expect(wrapper.findComponent(ApplySecurityLabels).exists()).toBe(result);
        });
      },
    );
  });
});
