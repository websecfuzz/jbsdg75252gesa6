import { shallowMount } from '@vue/test-utils';
import { GlButton, GlIntersectionObserver } from '@gitlab/ui';
import DuoCoreUpgradeCard from 'ee/ai/settings/components/duo_core_upgrade_card.vue';
import { SUPPORT_URL } from '~/sessions/new/constants';
import { mockTracking } from 'helpers/tracking_helper';

describe('DuoCoreUpgradeCard', () => {
  let wrapper;

  const createComponent = ({ addDuoProHref = 'https://customers.gitlab.com' } = {}) => {
    wrapper = shallowMount(DuoCoreUpgradeCard, {
      provide: {
        addDuoProHref,
      },
    });
  };

  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findUpgradeBtn = () => findButtons().at(0);
  const findContactSalesBtn = () => findButtons().at(1);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays pre-title, title and description', () => {
      expect(wrapper.text()).toContain('Upgrade to');
      expect(wrapper.text()).toContain('GitLab Duo Pro or Enterprise');
      expect(wrapper.text()).toContain(
        'Unlock advanced AI-native capabilities with the Premium or Ultimate tier designed for your development needs',
      );
    });

    it('renders a button for upgrading to duo pro', () => {
      expect(findButtons()).toHaveLength(2);
      expect(findUpgradeBtn().attributes('href')).toBe('https://customers.gitlab.com');
      expect(findUpgradeBtn().text()).toBe('Purchase Duo Pro seats');
    });

    it('renders a button for contacting sales about duo enterprise', () => {
      expect(findContactSalesBtn().attributes('href')).toBe(SUPPORT_URL);
      expect(findContactSalesBtn().text()).toBe('Contact sales for Duo Enterprise');
    });
  });

  describe('tracking', () => {
    let trackingSpy;
    const glIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    beforeEach(() => {
      createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('tracks page view on load', () => {
      glIntersectionObserver().vm.$emit('appear');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'pageview', {
        label: 'duo_core_add_on_upgrade_card',
      });
    });

    describe('when duo pro upgrade button is clicked', () => {
      it(`tracks the "duo_pro_purchase_seats" event`, async () => {
        await findUpgradeBtn().vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
          label: `duo_pro_purchase_seats`,
        });
      });
    });

    describe('when contact sales button is clicked', () => {
      it(`tracks the "duo_enterprise_contact_sales" event`, async () => {
        await findContactSalesBtn().vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
          label: `duo_enterprise_contact_sales`,
        });
      });
    });
  });
});
