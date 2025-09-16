import { shallowMount } from '@vue/test-utils';
import { GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_configuration/components/app.vue';
import ConfigureLabels from 'ee/security_configuration/components/security_labels/configure_labels.vue';

describe('Group Security configuration', () => {
  let wrapper;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findTab = () => wrapper.findComponent(GlTab);
  const findConfigureSecurityLabels = () => wrapper.findComponent(ConfigureLabels);

  const createComponent = () => {
    wrapper = shallowMount(App);
  };

  it('renders page heading, tab, description, and label configuration', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe('Security configuration');
    expect(findTab().attributes('title')).toBe('Security labels');
    expect(findTab().text()).toContain('Use security labels to categorize projects');
    expect(findConfigureSecurityLabels().exists()).toBe(true);
  });
});
