import { GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import BanMemberDropdownItem from 'ee/members/components/action_dropdowns/ban_member_dropdown_item.vue';
import { member } from 'jest/members/mock_data';
import { MEMBERS_TAB_TYPES } from '~/members/constants';

jest.mock('~/lib/utils/csrf', () => ({ token: 'mock-csrf-token' }));

Vue.use(Vuex);

const DEFAULT_MEMBERS_PATH = '/groups/foo-bar/-/group_members';

describe('BanMemberDropdownItem', () => {
  let wrapper;

  const createStore = () => {
    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: {
          namespaced: true,
          state: { memberPath: `${DEFAULT_MEMBERS_PATH}/:id` },
        },
      },
    });
  };

  const createComponent = () => {
    wrapper = shallowMount(BanMemberDropdownItem, {
      store: createStore(),
      provide: { namespace: MEMBERS_TAB_TYPES.user },
      slots: { default: 'Dropdown item text' },
      propsData: { member },
    });
  };

  const findForm = () => wrapper.find('form');

  beforeEach(() => {
    createComponent();
  });

  it('renders a form with correct attributes', () => {
    expect(findForm().attributes('action')).toBe(`${DEFAULT_MEMBERS_PATH}/${member.id}/ban`);
    expect(findForm().attributes('method')).toBe('post');
  });

  it('renders a form with correct inputs', () => {
    expect(findForm().find('input[name="_method"]').attributes('value')).toBe('put');
    expect(findForm().find('input[name="authenticity_token"]').attributes('value')).toBe(
      'mock-csrf-token',
    );
  });

  it('submits the form when clicked', () => {
    const submitSpy = jest.spyOn(findForm().element, 'submit');
    wrapper.findComponent(GlDisclosureDropdownItem).vm.$emit('action');
    expect(submitSpy).toHaveBeenCalled();
  });
});
