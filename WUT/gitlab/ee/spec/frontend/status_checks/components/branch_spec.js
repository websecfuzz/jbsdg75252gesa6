import { shallowMount } from '@vue/test-utils';
import Branch from 'ee/status_checks/components/branch.vue';

describe('Status checks branch', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(Branch, {
      propsData: props,
    });
  };

  const findBranch = () => wrapper.find('span');

  it('renders "All branches" if no branch is given', () => {
    createWrapper();

    expect(findBranch().text()).toBe('All branches');
    expect(findBranch().classes('monospace')).toBe(false);
  });

  it('renders all of the branches names', () => {
    createWrapper({ branches: [{ name: 'Foo' }, { name: 'Bar' }] });

    expect(findBranch().text()).toBe('Foo, Bar');
    expect(findBranch().classes('monospace')).toBe(true);
  });
});
