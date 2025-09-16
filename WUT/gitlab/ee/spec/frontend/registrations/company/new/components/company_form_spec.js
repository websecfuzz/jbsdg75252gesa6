import { GlButton, GlForm } from '@gitlab/ui';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trackCompanyForm } from 'ee/google_tag_manager';

const SUBMIT_PATH = '_submit_path_';

jest.mock('ee/google_tag_manager');

describe('CompanyForm', () => {
  let wrapper;

  const createComponent = (provideData = {}) => {
    return shallowMountExtended(CompanyForm, {
      provide: {
        submitPath: SUBMIT_PATH,
        user: {
          firstName: 'Joe',
          lastName: 'Doe',
          showNameFields: true,
          companyName: null,
          phoneNumber: null,
          country: '',
          state: '',
          emailDomain: '_email_domain_',
        },
        trackActionForErrors: '_trackActionForErrors_',
        showFormFooter: true,
        ...provideData,
      },
    });
  };

  const findSubmitButton = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findFooterDescriptionText = () => wrapper.findByTestId('footer_description_text');

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      testid
      ${'first_name'}
      ${'last_name'}
      ${'company_name'}
      ${'country'}
      ${'phone_number'}
    `('has the correct form input in the form content', ({ testid }) => {
      expect(findFormInput(testid).exists()).toBe(true);
    });
  });

  describe('when showFormFooter is false', () => {
    beforeEach(() => {
      wrapper = createComponent({ showFormFooter: false });
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue');
    });

    it('does not display footer', () => {
      expect(findFooterDescriptionText().exists()).toBe(false);
    });
  });

  describe('when showFormFooter is true', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue with trial');
    });

    it('displays correct footer text', () => {
      expect(findFooterDescriptionText().exists()).toBe(true);
      expect(findFooterDescriptionText().text()).toBe(
        'Your free Ultimate & GitLab Duo Enterprise Trial lasts for 60 days. After this period, you can maintain a GitLab Free account forever, or upgrade to a paid plan.',
      );
    });
  });

  describe('submitting', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('has a submit button', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
    });

    it('displays form with correct action', () => {
      expect(findForm().attributes('action')).toBe(SUBMIT_PATH);
    });

    it('tracks form submission', () => {
      findForm().vm.$emit('submit');

      expect(trackCompanyForm).toHaveBeenCalledWith('ultimate_trial', '_email_domain_');
    });
  });
});
