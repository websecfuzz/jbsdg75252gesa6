import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AdminUsersFilterApp from '~/admin/users/components/admin_users_filter_app.vue';

jest.mock('~/lib/utils/url_utility', () => {
  return {
    ...jest.requireActual('~/lib/utils/url_utility'),
    visitUrl: jest.fn(),
  };
});

describe('AdminUsersFilterApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(AdminUsersFilterApp);
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findAvailableTokens = () => findFilteredSearch().props('availableTokens');

  it('includes the auditors option', () => {
    createComponent();
    const currentOptions = findAvailableTokens().flatMap(({ options }) =>
      options.map(({ value }) => value),
    );

    expect(currentOptions).toContain('auditors');
  });
});
