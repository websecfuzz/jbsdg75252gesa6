import { GlDatepicker, GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PlaceholderBypassDatePicker from 'ee/groups/settings/permissions/components/placeholder_bypass_date_picker.vue';

describe('PlaceholderBypassDatePicker', () => {
  let wrapper;

  const defaultProps = {
    minDate: new Date('2025-05-28'),
    inputName: 'placeholder-user-bypass-datepicker',
    disabled: false,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(PlaceholderBypassDatePicker, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  it('renders the correct label', () => {
    createComponent();

    expect(wrapper.findComponent(GlFormGroup).attributes('label')).toEqual('Expiry date');
  });

  it('sets the inputName on GlDatepicker', () => {
    createComponent();
    expect(wrapper.findComponent(GlDatepicker).props('inputName')).toEqual(defaultProps.inputName);
  });

  it('sets the minDate on GlDatepicker', () => {
    createComponent();

    expect(wrapper.findComponent(GlDatepicker).props('minDate')).toEqual(defaultProps.minDate);
  });

  it('sets the expiry date on GlDatepicker when currentExpiryDate is provided', () => {
    const expiryDate = '2025-06-15';
    createComponent({ currentExpiryDate: expiryDate });

    expect(wrapper.findComponent(GlDatepicker).props('value')).toEqual(new Date(expiryDate));
  });

  it('allows disabled state to be overridden', () => {
    createComponent({ disabled: false });
    expect(wrapper.findComponent(GlDatepicker).props('disabled')).toBe(false);
  });
});
