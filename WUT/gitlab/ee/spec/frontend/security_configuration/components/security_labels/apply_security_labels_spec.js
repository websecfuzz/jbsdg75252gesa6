import { shallowMount } from '@vue/test-utils';
import ApplySecurityLabels from 'ee/security_configuration/security_labels/components/apply_security_labels.vue';

describe('ApplySecurityLabels', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ApplySecurityLabels);
  };

  it('renders page heading, tab, and description', () => {
    createComponent();

    expect(wrapper.text()).toContain('Security labels help classify and organize your projects');
  });
});
