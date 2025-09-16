import { GlButton, GlForm, GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import TrialCreateLeadForm from 'ee/trials/components/trial_create_lead_form.vue';
import CountryOrRegionSelector from 'jh_else_ee/trials/components/country_or_region_selector.vue';
import { TRIAL_TERMS_TEXT } from 'ee/trials/constants';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import GlFieldErrors from '~/gl_field_errors';
import {
  FORM_DATA,
  NO_USER_LAST_NAME_FORM_DATA,
  SUBMIT_PATH,
  GTM_SUBMIT_EVENT_LABEL,
} from './mock_data';

jest.mock('~/gl_field_errors');
jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialLeadSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('TrialCreateLeadForm', () => {
  let wrapper;
  const submitButtonText = 'Some Text';

  const createComponent = ({
    mountFunction = shallowMountExtended,
    provide = {},
    formData = FORM_DATA,
    propsData = { border: false },
  } = {}) =>
    mountFunction(TrialCreateLeadForm, {
      provide: {
        submitPath: SUBMIT_PATH,
        user: formData,
        gtmSubmitEventLabel: GTM_SUBMIT_EVENT_LABEL,
        submitButtonText,
        ...provide,
      },
      propsData,
      stubs: {
        CountryOrRegionSelector: stubComponent(CountryOrRegionSelector, {
          template: `<div></div>`,
        }),
      },
    });

  const findForm = () => wrapper.findComponent(GlForm);
  const findButton = () => wrapper.findComponent(GlButton);
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findTermsSprintf = () => wrapper.findComponent(GlSprintf);

  describe('rendering', () => {
    const FORM_FIELDS = [
      'first-name-field',
      'last-name-field',
      'company-name-field',
      'phone-number-field',
    ];

    describe('with default props', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it.each`
        testid                  | value
        ${'first-name-field'}   | ${'Joe'}
        ${'last-name-field'}    | ${''}
        ${'company-name-field'} | ${'ACME'}
        ${'phone-number-field'} | ${'192919'}
      `('has the default injected value for $testid', ({ testid, value }) => {
        expect(findFormInput(testid).attributes('value')).toBe(value);
      });

      it('has the correct form input in the form content', () => {
        FORM_FIELDS.forEach((f) => expect(findFormInput(f).exists()).toBe(true));
        FORM_FIELDS.forEach((f) => expect(findFormInput(f).isVisible()).toBe(true));
      });

      it('has correct terms and conditions content', () => {
        expect(findTermsSprintf().attributes('message')).toBe(TRIAL_TERMS_TEXT);
      });
    });

    describe('border prop', () => {
      it('does not add border classes when border is false', () => {
        wrapper = createComponent({ propsData: { border: false } });

        expect(findForm().classes()).not.toContain('gl-border-1');
      });

      it('adds border classes when border is true', () => {
        wrapper = createComponent({ propsData: { border: true } });

        expect(findForm().classes()).toContain('gl-border-1');
      });
    });

    describe('with hidden name fields', () => {
      beforeEach(() => {
        wrapper = createComponent({ formData: NO_USER_LAST_NAME_FORM_DATA });
      });

      it.each`
        testid                  | value
        ${'first-name-field'}   | ${'Joe'}
        ${'last-name-field'}    | ${'Doe'}
        ${'company-name-field'} | ${'ACME'}
        ${'phone-number-field'} | ${'192919'}
      `('has the default injected value for $testid', ({ testid, value }) => {
        expect(findFormInput(testid).attributes('value')).toBe(value);
      });

      it('has the correct form input in the form content when name fields are hidden', () => {
        const NAME_FIELDS = ['first-name-field', 'last-name-field'];

        FORM_FIELDS.forEach((f) => expect(findFormInput(f).exists()).toBe(true));
        NAME_FIELDS.forEach((f) => expect(findFormInput(f).isVisible()).toBe(false));
      });
    });
  });

  describe('field errors initialization', () => {
    beforeEach(() => {
      GlFieldErrors.mockClear();

      wrapper = createComponent();
    });

    it('initializes GlFieldErrors on mount', () => {
      expect(GlFieldErrors).toHaveBeenCalledTimes(1);
    });
  });

  it('has the submit button text on the submit button', () => {
    wrapper = createComponent();

    expect(findButton().text()).toBe(submitButtonText);
  });

  describe('submitting', () => {
    beforeEach(() => {
      wrapper = createComponent({ mountFunction: mountExtended });
    });

    it('tracks the saas Trial submitting', () => {
      findForm().trigger('submit');

      expect(trackSaasTrialLeadSubmit).toHaveBeenCalledWith(
        GTM_SUBMIT_EVENT_LABEL,
        FORM_DATA.emailDomain,
      );
    });

    it.each`
      value                    | result
      ${'+1 (121) 22-12-23'}   | ${false}
      ${'+12190AX '}           | ${false}
      ${'Tel:129120'}          | ${false}
      ${'11290+12'}            | ${false}
      ${FORM_DATA.phoneNumber} | ${true}
    `('validates the phone number with value of `$value`', ({ value, result }) => {
      expect(findFormInput('phone-number-field').exists()).toBe(true);

      findFormInput('phone-number-field').setValue(value);

      findForm().trigger('submit');

      expect(findFormInput('phone-number-field').element.checkValidity()).toBe(result);
    });
  });
});
