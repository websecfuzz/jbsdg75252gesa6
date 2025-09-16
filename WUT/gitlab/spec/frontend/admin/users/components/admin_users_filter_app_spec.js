import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { visitUrl, getBaseURL } from '~/lib/utils/url_utility';
import AdminUsersFilterApp from '~/admin/users/components/admin_users_filter_app.vue';
import { expectedTokens, expectedAccessLevelToken } from '../mock_data';

const mockToken = [
  {
    type: 'access_level',
    value: { data: 'admins', operator: '=' },
  },
];

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

  it('includes all the tokens', () => {
    createComponent();

    expect(findAvailableTokens()).toMatchObject(expectedTokens);
  });

  describe('when a token is selected', () => {
    /**
     * Currently BE support only one filter at the time
     * https://gitlab.com/gitlab-org/gitlab/-/issues/254377
     */
    it('discard all other tokens', async () => {
      createComponent();
      findFilteredSearch().vm.$emit('input', mockToken);
      await nextTick();

      expect(findAvailableTokens()).toEqual([expectedAccessLevelToken]);
    });
  });

  describe('when a text token is selected', () => {
    it('includes all the tokens', async () => {
      createComponent();
      findFilteredSearch().vm.$emit('input', [
        {
          type: 'filtered-search-term',
          value: { data: 'mytext' },
        },
      ]);
      await nextTick();

      expect(findAvailableTokens()).toEqual(expectedTokens);
    });
  });

  describe('initialize tokens based on query search parameters', () => {
    /**
     * Currently BE support only one filter at the time
     * https://gitlab.com/gitlab-org/gitlab/-/issues/254377
     */
    it('includes only one token if `filter` query parameter the TOKENS', () => {
      window.history.replaceState({}, '', '/?filter=admins');
      createComponent();

      expect(findAvailableTokens()).toEqual([expectedAccessLevelToken]);
    });

    it('replace the initial token when another token is selected', async () => {
      window.history.replaceState({}, '', '/?filter=banned');
      createComponent();
      findFilteredSearch().vm.$emit('input', mockToken);
      await nextTick();

      expect(findAvailableTokens()).toEqual([expectedAccessLevelToken]);
    });
  });

  describe('when user submit a search', () => {
    it('keeps `sort` and adds new `search_query` and `filter` query parameter and visit page', async () => {
      window.history.replaceState({}, '', '/?filter=banned&sort=oldest_sign_in');
      createComponent();
      findFilteredSearch().vm.$emit('submit', [...mockToken, 'mytext']);
      await nextTick();

      expect(visitUrl).toHaveBeenCalledWith(
        `${getBaseURL()}/?filter=admins&search_query=mytext&sort=oldest_sign_in`,
      );
    });
  });
});
