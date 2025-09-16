import { shallowMount } from '@vue/test-utils';

import App from '~/pages/groups/new/components/app.vue';
import NewNamespacePage from '~/vue_shared/new_namespace/new_namespace_page.vue';

describe('App component', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(App, {
      propsData: { rootPath: '/', groupsUrl: '/dashboard/groups', ...propsData },
    });
  };

  const findNewNamespacePage = () => wrapper.findComponent(NewNamespacePage);

  const findCreateGroupPanel = () =>
    findNewNamespacePage()
      .props('panels')
      .find((panel) => panel.name === 'create-group-pane');

  it('creates correct component for group creation', () => {
    createComponent();

    expect(findNewNamespacePage().props('initialBreadcrumbs')).toEqual([
      { href: '/', text: 'Your work' },
      { href: '/dashboard/groups', text: 'Groups' },
      { href: '#', text: 'New group' },
    ]);
    expect(findCreateGroupPanel().title).toBe('Create group');
  });

  it('creates correct component for subgroup creation', () => {
    const detailProps = {
      parentGroupName: 'parent',
      importExistingGroupPath: '/path',
    };

    const props = { ...detailProps, parentGroupUrl: '/parent' };

    createComponent(props);

    expect(findNewNamespacePage().props('initialBreadcrumbs')).toEqual([
      { href: '/parent', text: 'parent' },
      { href: '#', text: 'New subgroup' },
    ]);
    expect(findCreateGroupPanel().title).toBe('Create subgroup');
    expect(findCreateGroupPanel().detailProps).toEqual(detailProps);
  });
});
