import { nextTick } from 'vue';
import { GlFormRadioGroup, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BeforeSubmitUserCapOverLicensedUsersModal from 'ee/pages/admin/application_settings/general/components/before_submit_user_cap_over_licensed_users_modal.vue';
import SeatControlMemberPromotionManagement from 'ee/pages/admin/application_settings/general/components/seat_control_member_promotion_management.vue';
import SeatControlSection from 'ee/pages/admin/application_settings/general/components/seat_control_section.vue';
import { SEAT_CONTROL } from 'ee/pages/admin/application_settings/general/constants';

describe('SeatControlSection', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSeatControlSettings = () => wrapper.findComponent(GlFormRadioGroup);
  const findSeatControlMemberPromotionManagement = () =>
    wrapper.findComponent(SeatControlMemberPromotionManagement);
  const findUserCapInput = () => wrapper.findByTestId('user-cap-input');
  const findUserCapHiddenInput = () => wrapper.findByTestId('user-cap-input-hidden');
  const findUserCapModal = () => wrapper.findComponent(BeforeSubmitUserCapOverLicensedUsersModal);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(SeatControlSection, {
      provide: {
        licensedUserCount: '0',
        newUserSignupsCap: '',
        pendingUserCount: 0,
        promotionManagementAvailable: false,
        seatControl: SEAT_CONTROL.OFF,
        glLicensedFeatures: { seatControl: true },
        ...provide,
      },
      stubs: { GlSprintf },
    });
  };

  it('passes the proper props to the modal', () => {
    mountComponent({ provide: { newUserSignupsCap: '13' } });

    expect(findUserCapModal().props()).toMatchObject({
      licensedUserCount: 0,
      userCap: 13,
    });
  });

  describe('with member promotion management available', () => {
    beforeEach(() => {
      mountComponent({ provide: { promotionManagementAvailable: true } });
    });

    it('will display the SeatControlMemberPromotionManagement', () => {
      expect(findSeatControlMemberPromotionManagement().exists()).toBe(true);
    });
  });

  describe('with member promotion management unavailable', () => {
    it('will not display SeatControlMemberPromotionManagement', () => {
      mountComponent({ provide: { promotionManagementAvailable: false } });

      expect(findSeatControlMemberPromotionManagement().exists()).toBe(false);
    });
  });

  describe('user cap help text', () => {
    it('displays the default message', () => {
      mountComponent();

      expect(wrapper.text()).toContain(
        'Users added beyond this limit require administrator approval. Leave blank for unlimited.',
      );
    });

    describe('with a license', () => {
      it('displays a message related to true up', () => {
        mountComponent({ provide: { licensedUserCount: 10 } });

        expect(wrapper.text()).toContain(
          'A user cap that exceeds the current licensed user count (10) may result in seat overages.',
        );
      });
    });
  });

  describe('should verify user auto approval', () => {
    describe('when set to Seat Control > Open Access', () => {
      beforeEach(() => {
        mountComponent({ provide: { newUserSignupsCap: '', seatControl: SEAT_CONTROL.OFF } });
      });

      describe('when switching to Seat Control > Block Overages', () => {
        it('emits false', async () => {
          findSeatControlSettings().vm.$emit('change', SEAT_CONTROL.BLOCK_OVERAGES);

          await nextTick();

          expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([false]);
        });
      });

      describe.each(['', 13])(
        'when switching to Seat Control > User Cap (value: %d)',
        (newUserCap) => {
          it('emits false', async () => {
            findUserCapInput().vm.$emit('input', newUserCap);
            findSeatControlSettings().vm.$emit('change', SEAT_CONTROL.USER_CAP);

            await nextTick();

            expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([false]);
          });
        },
      );
    });

    describe('when set to Seat Control > Block Overages', () => {
      beforeEach(() => {
        mountComponent({
          provide: { newUserSignupsCap: '', seatControl: SEAT_CONTROL.BLOCK_OVERAGES },
        });
      });

      describe('when switching to Seat Control > Open Access', () => {
        it('emits false', async () => {
          findSeatControlSettings().vm.$emit('change', SEAT_CONTROL.OFF);

          await nextTick();

          expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([false]);
        });
      });

      describe.each(['', 13])(
        'when switching to Seat Control > User Cap (value: %d)',
        (newUserCap) => {
          it('emits false', async () => {
            findUserCapInput().vm.$emit('input', newUserCap);
            findSeatControlSettings().vm.$emit('change', SEAT_CONTROL.USER_CAP);

            await nextTick();

            expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([false]);
          });
        },
      );
    });

    describe('when set to Seat Control > User Cap', () => {
      beforeEach(() => {
        mountComponent({
          provide: { newUserSignupsCap: 7, seatControl: SEAT_CONTROL.USER_CAP },
        });
      });

      describe('when switching to Seat Control > Open Access', () => {
        it('emits false', async () => {
          findSeatControlSettings().vm.$emit('change', SEAT_CONTROL.OFF);

          await nextTick();

          expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([true]);
        });
      });

      describe.each`
        initialUserCap | userCap | expected
        ${''}          | ${13}   | ${false}
        ${13}          | ${16}   | ${true}
        ${13}          | ${9}    | ${false}
        ${13}          | ${''}   | ${true}
      `(
        'when changing the Seat Control > User Cap value to $userCap',
        ({ initialUserCap, userCap, expected }) => {
          beforeEach(() => {
            mountComponent({
              provide: { newUserSignupsCap: initialUserCap, seatControl: SEAT_CONTROL.USER_CAP },
            });
          });

          it(`emits ${expected}`, async () => {
            findUserCapInput().vm.$emit('input', userCap);

            await nextTick();

            expect(wrapper.emitted('checkUsersAutoApproval')[0]).toEqual([expected]);
          });
        },
      );
    });
  });

  describe.each([
    [SEAT_CONTROL.OFF, ['true', undefined]],
    [SEAT_CONTROL.USER_CAP, [undefined, 'disabled']],
    [SEAT_CONTROL.BLOCK_OVERAGES, ['true', undefined]],
  ])('with seat control to value (%s)', (seatControl, [isDisabled, idHiddenDisabled]) => {
    beforeEach(() => {
      mountComponent({ provide: { seatControl } });
    });

    it(`sets the input value to ${isDisabled}`, () => {
      expect(findUserCapInput().attributes().disabled).toBe(isDisabled);
    });

    it(`sets the hidden input value to ${idHiddenDisabled}`, () => {
      expect(findUserCapHiddenInput().attributes().disabled).toBe(idHiddenDisabled);
    });
  });

  describe('when the user cap modal emits the primary event', () => {
    it('emits a submit event', () => {
      mountComponent();
      findUserCapModal().vm.$emit('primary');

      expect(wrapper.emitted('submit')).toHaveLength(1);
    });
  });
});
