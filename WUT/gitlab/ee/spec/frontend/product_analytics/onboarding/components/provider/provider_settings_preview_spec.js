import { shallowMount } from '@vue/test-utils';
import ProviderSettingsPreview from 'ee/product_analytics/onboarding/components/providers/provider_settings_preview.vue';

describe('ProviderSettingsPreview', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ProviderSettingsPreview, {
      propsData: {
        configuratorConnectionString: 'test-connection-string',
        collectorHost: 'test-collector-host',
        cubeApiBaseUrl: 'test-cube-api-url',
        cubeApiKey: 'test-cube-api-key',
        ...props,
      },
    });
  };

  it('renders the component with the correct settings', () => {
    createComponent();

    expect(wrapper.findAll('dt')).toHaveLength(4);
    expect(wrapper.findAll('dd')).toHaveLength(4);

    expect(wrapper.findAll('dt').at(0).text()).toBe('Snowplow configurator connection string');
    expect(wrapper.findAll('dd').at(0).text()).toBe('****************');

    expect(wrapper.findAll('dt').at(1).text()).toBe('Collector host');
    expect(wrapper.findAll('dd').at(1).text()).toBe('test-collector-host');

    expect(wrapper.findAll('dt').at(2).text()).toBe('Cube API URL');
    expect(wrapper.findAll('dd').at(2).text()).toBe('test-cube-api-url');

    expect(wrapper.findAll('dt').at(3).text()).toBe('Cube API key');
    expect(wrapper.findAll('dd').at(3).text()).toBe('****************');
  });

  it('does not render settings with empty values', () => {
    createComponent({
      configuratorConnectionString: '',
      collectorHost: '',
      cubeApiBaseUrl: '',
      cubeApiKey: '',
    });

    expect(wrapper.findAll('dt')).toHaveLength(0);
    expect(wrapper.findAll('dd')).toHaveLength(0);
  });

  it('masks sensitive values with asterisks', () => {
    createComponent({
      configuratorConnectionString: 'sensitive-connection-string',
      cubeApiKey: 'sensitive-api-key',
    });

    expect(wrapper.findAll('dd').at(0).text()).toBe('****************');
    expect(wrapper.findAll('dd').at(3).text()).toBe('****************');
  });

  it('limits the masked value length to 16 characters', () => {
    createComponent({
      configuratorConnectionString: 'a-very-long-sensitive-connection-string',
      cubeApiKey: 'a-very-long-sensitive-api-key',
    });

    expect(wrapper.findAll('dd').at(0).text()).toHaveLength(16);
    expect(wrapper.findAll('dd').at(3).text()).toHaveLength(16);
  });
});
