import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('AiCommonSettings', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCommonSettings, {
      propsData: {
        hasParentFormChanged: false,
        ...props,
      },
      provide: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: true,
        onGeneralSettingsPage: false,
        ...provide,
      },
      stubs: {
        GlSprintf: {
          template: `
            <span>
              <slot name="link" v-bind="{ content: $attrs.message }">
              </slot>
            </span>
          `,
          components: {
            GlLink,
          },
        },
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findGeneralSettingsDescriptionText = () =>
    wrapper.findByTestId('general-settings-subtitle');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findForm = () => wrapper.findComponent(AiCommonSettingsForm);

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the AiCommonSettingsForm component', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('emits submit event with correct data when form is submitted via AiCommonSettingsForm component', async () => {
    await findForm().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    await findForm().vm.$emit('experiment-checkbox-changed', true);
    await findForm().vm.$emit('duo-core-checkbox-changed', true);
    findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
    const emittedData = wrapper.emitted('submit')[0][0];
    expect(emittedData).toEqual({
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      experimentFeaturesEnabled: true,
      duoCoreFeaturesEnabled: true,
      promptCacheEnabled: true,
    });
  });

  describe('when on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
    });

    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes props to settings-block component', () => {
      expect(findSettingsBlock().props()).toEqual({
        expanded: false,
        id: null,
        title: 'GitLab Duo features',
      });
    });

    it('renders the settings block description text', () => {
      expect(findGeneralSettingsDescriptionText().text()).toContain(
        'Configure AI-native GitLab Duo features',
      );
    });
  });

  describe('when not on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: false } });
    });

    it('renders PageHeading component', () => {
      expect(findPageHeading().exists()).toBe(true);
    });

    it('renders correct title in PageHeading', () => {
      expect(findPageHeading().props('heading')).toBe('Configuration');
    });

    it('renders correct subtitle in PageHeading', () => {
      expect(wrapper.findByTestId('configuration-page-subtitle').exists()).toBe(true);
    });
  });
});
