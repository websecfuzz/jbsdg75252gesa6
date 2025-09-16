import { GlDatepicker } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import waitForPromises from 'helpers/wait_for_promises';
import ExpirationDatepicker from '~/members/components/table/expiration_datepicker.vue';
import { MEMBERS_TAB_TYPES } from '~/members/constants';
import { member } from '../../mock_data';

Vue.use(Vuex);

describe('ExpirationDatepicker', () => {
  // March 15th, 2020 3:00
  useFakeDate(2020, 2, 15, 3);

  let wrapper;
  let actions;
  let resolveUpdateMemberExpiration;
  const $toast = {
    show: jest.fn(),
  };

  const createStore = () => {
    actions = {
      updateMemberExpiration: jest.fn(
        () =>
          new Promise((resolve) => {
            resolveUpdateMemberExpiration = resolve;
          }),
      ),
    };

    return new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.user]: { namespaced: true, actions },
      },
    });
  };

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ExpirationDatepicker, {
      propsData: {
        member,
        permissions: { canUpdate: true },
        ...propsData,
      },
      provide: {
        namespace: MEMBERS_TAB_TYPES.user,
      },
      store: createStore(),
      mocks: {
        $toast,
      },
    });
  };

  const findDatepicker = () => wrapper.findComponent(GlDatepicker);

  describe('datepicker input', () => {
    it('sets `member.expiresAt` as initial date', async () => {
      createComponent({ member: { ...member, expiresAt: '2020-03-17T00:00:00Z' } });

      await nextTick();

      expect(findDatepicker().props('value')).toEqual(new Date('2020-03-17'));
    });
  });

  describe('props', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets `minDate` prop as tomorrow', () => {
      expect(findDatepicker().props('minDate').toISOString()).toBe(
        new Date('2020-3-16').toISOString(),
      );
    });

    it('sets `target` prop as `null` so datepicker opens on focus', () => {
      expect(findDatepicker().props('target')).toBe(null);
    });

    it("sets `container` prop as `null` so table styles don't affect the datepicker styles", () => {
      expect(findDatepicker().props('container')).toBe(null);
    });

    it('shows clear button', () => {
      expect(findDatepicker().props('showClearButton')).toBe(true);
    });
  });

  describe('when datepicker is changed', () => {
    beforeEach(() => {
      createComponent();

      findDatepicker().vm.$emit('input', new Date('2020-03-17'));
    });

    it('calls `updateMemberExpiration` Vuex action', () => {
      expect(actions.updateMemberExpiration).toHaveBeenCalledWith(expect.any(Object), {
        memberId: member.id,
        expiresAt: new Date('2020-03-17'),
      });
    });

    it('displays toast when successful', async () => {
      resolveUpdateMemberExpiration();
      await waitForPromises();

      expect($toast.show).toHaveBeenCalledWith('Expiration date updated successfully.');
    });

    it('disables dropdown while waiting for `updateMemberExpiration` to resolve', async () => {
      expect(findDatepicker().props('disabled')).toBe(true);

      resolveUpdateMemberExpiration();
      await waitForPromises();

      expect(findDatepicker().props('disabled')).toBe(false);
    });
  });

  describe('when datepicker is cleared', () => {
    beforeEach(async () => {
      createComponent();

      await findDatepicker().vm.$emit('input', new Date('2020-03-17'));
      await findDatepicker().vm.$emit('clear');
    });

    it('calls `updateMemberExpiration` Vuex action', () => {
      expect(actions.updateMemberExpiration).toHaveBeenCalledWith(expect.any(Object), {
        memberId: member.id,
        expiresAt: null,
      });
    });

    it('displays toast when successful', async () => {
      resolveUpdateMemberExpiration();
      await waitForPromises();

      expect($toast.show).toHaveBeenCalledWith('Expiration date removed successfully.');
    });

    it('disables datepicker while waiting for `updateMemberExpiration` to resolve', async () => {
      expect(findDatepicker().props('disabled')).toBe(true);

      resolveUpdateMemberExpiration();
      await waitForPromises();

      expect(findDatepicker().props('disabled')).toBe(false);
    });
  });

  describe('when user does not have `canUpdate` permissions', () => {
    it('disables datepicker', () => {
      createComponent({ permissions: { canUpdate: false } });

      expect(findDatepicker().props('disabled')).toBe(true);
    });
  });
});
