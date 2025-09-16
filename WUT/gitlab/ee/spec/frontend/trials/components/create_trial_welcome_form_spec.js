import { GlForm, GlFormFields, GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import CreateTrialWelcomeForm from 'ee/trials/components/create_trial_welcome_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from 'ee_jest/hand_raise_leads/components/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialLeadSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('CreateTrialWelcomeForm', () => {
  let wrapper;
  const submitPath = '/trials/welcome';
  const gtmSubmitEventLabel = 'trial_welcome_form_submit';

  const defaultUserData = {
    firstName: 'Alice',
    lastName: 'Johnson',
    companyName: 'Example Corp',
    country: 'US',
    state: 'NY',
    emailDomain: 'example.com',
  };

  const createComponent = async ({
    userData = defaultUserData,
    propsData = {},
    countriesLoading = false,
    statesLoading = false,
    data,
  } = {}) => {
    const mockResolvers = {
      Query: {
        countries() {
          if (countriesLoading) {
            return new Promise(() => {});
          }
          return COUNTRIES;
        },
        states() {
          if (statesLoading) {
            return new Promise(() => {});
          }
          return STATES;
        },
      },
    };

    const component = shallowMountExtended(CreateTrialWelcomeForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        userData,
        submitPath,
        gtmSubmitEventLabel,
        ...propsData,
      },
      stubs: {
        GlButton,
      },
      data,
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return component;
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findCountrySelect = () => wrapper.findByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findByTestId('state-dropdown');
  const fieldsProps = () => findFormFields().props('fields');
  const formValues = () => findFormFields().props('modelValue') || wrapper.vm.formValues;

  describe('rendering', () => {
    describe('initialization', () => {
      it('initializes form values from userData prop', async () => {
        wrapper = await createComponent();

        expect(formValues()).toEqual({
          first_name: defaultUserData.firstName,
          last_name: defaultUserData.lastName,
          company_name: defaultUserData.companyName,
          country: defaultUserData.country,
          state: defaultUserData.state,
          group_name: '',
          project_name: '',
        });
      });

      it('handles missing userData fields gracefully', async () => {
        wrapper = await createComponent({
          userData: {
            emailDomain: 'test.com',
          },
        });

        expect(formValues()).toEqual({
          first_name: undefined, // userData.firstName is undefined
          last_name: undefined, // userData.lastName is undefined
          company_name: undefined, // userData.companyName is undefined
          country: undefined, // userData.country is undefined
          state: undefined, // userData.state is undefined
          group_name: '',
          project_name: '',
        });
      });

      it('initializes selected country and state from userData', async () => {
        wrapper = await createComponent();

        expect(wrapper.vm.formValues.country).toBe(defaultUserData.country);
        expect(wrapper.vm.formValues.state).toBe(defaultUserData.state);
      });

      it('initializes group and project names as empty strings', async () => {
        wrapper = await createComponent();

        expect(wrapper.vm.formValues.group_name).toBe('');
        expect(wrapper.vm.formValues.project_name).toBe('');
      });
    });

    describe('with default props', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('renders the form with correct action and method', () => {
        expect(findForm().attributes('action')).toBe(submitPath);
        expect(findForm().attributes('method')).toBe('post');
      });

      it('passes the correct fields to GlFormFields', () => {
        expect(findFormFields().exists()).toBe(true);

        const expectedFields = [
          { key: 'first_name', name: 'first_name' },
          { key: 'last_name', name: 'last_name' },
          { key: 'company_name', name: 'company_name' },
          { key: 'country', name: undefined },
          { key: 'state', name: undefined },
          { key: 'group_name', name: 'group_name' },
          { key: 'project_name', name: 'project_name' },
        ];

        expectedFields.forEach(({ key, name }) => {
          if (fieldsProps()[key]) {
            if (name !== undefined && fieldsProps()[key].inputAttrs) {
              expect(fieldsProps()[key].inputAttrs).toHaveProperty('name', name);
            }
          }
        });
      });

      it('correctly updates GlFormFields values on input update', async () => {
        const initialValues = {
          first_name: defaultUserData.firstName,
          last_name: defaultUserData.lastName,
          company_name: defaultUserData.companyName,
          country: defaultUserData.country,
          state: defaultUserData.state,
          group_name: '',
          project_name: '',
        };
        expect(formValues()).toEqual(initialValues);

        const updatedValues = {
          ...initialValues,
          company_name: 'Updated Company Name',
        };

        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();

        expect(wrapper.vm.formValues.company_name).toBe('Updated Company Name');
      });
    });

    describe('country field', () => {
      it('does not show country field when Apollo is loading countries', async () => {
        wrapper = await createComponent({ countriesLoading: true });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('country');
      });

      it('shows country field when Apollo is not loading countries', async () => {
        wrapper = await createComponent();
        await nextTick();

        expect(fieldsProps()).toHaveProperty('country');
      });
    });

    describe('state field', () => {
      it('does not show state field when Apollo is loading states', async () => {
        wrapper = await createComponent({ statesLoading: true });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('shows state field when country requires states and states are loaded', async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: COUNTRY_WITH_STATES },
        });
        await nextTick();

        expect(fieldsProps()).toHaveProperty('state');
        expect(findStateSelect().exists()).toBe(true);
      });

      it('does not show state field when country does not require states', async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: 'NL' },
        });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });
    });

    describe('group and project name fields', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('always includes group name field', () => {
        expect(fieldsProps()).toHaveProperty('group_name');
        expect(fieldsProps().group_name.label).toBe(' ');
      });

      it('always includes project name field', () => {
        expect(fieldsProps()).toHaveProperty('project_name');
        expect(fieldsProps().project_name.label).toBe(' ');
      });
    });
  });

  describe('field validations', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    describe('name field validations', () => {
      it.each`
        value     | result
        ${null}   | ${'First name is required.'}
        ${''}     | ${'First name is required.'}
        ${'John'} | ${''}
      `('validates the first_name with value of `$value`', ({ value, result }) => {
        if (fieldsProps().first_name) {
          const firstNameValidator = fieldsProps().first_name.validators[0];
          expect(firstNameValidator(value)).toBe(result);
        }
      });

      it.each`
        value    | result
        ${null}  | ${'Last name is required.'}
        ${''}    | ${'Last name is required.'}
        ${'Doe'} | ${''}
      `('validates the last_name with value of `$value`', ({ value, result }) => {
        if (fieldsProps().last_name) {
          const lastNameValidator = fieldsProps().last_name.validators[0];
          expect(lastNameValidator(value)).toBe(result);
        }
      });
    });

    describe('company_name field validations', () => {
      it.each`
        value       | result
        ${null}     | ${'Company name is required.'}
        ${''}       | ${'Company name is required.'}
        ${'TestCo'} | ${''}
      `('validates the company_name with value of `$value`', ({ value, result }) => {
        const companyNameValidator = fieldsProps().company_name.validators[0];
        expect(companyNameValidator(value)).toBe(result);
      });
    });

    describe('group name field validations', () => {
      it('validates group name is required', async () => {
        wrapper = await createComponent();

        const groupNameValidator = fieldsProps().group_name.validators[0];

        // Test empty value
        expect(groupNameValidator('')).toBe('Group name is required.');

        // Test with value
        expect(groupNameValidator('My Test Group')).toBe('');
      });
    });

    describe('project name field validations', () => {
      it('validates project name is required', async () => {
        wrapper = await createComponent();

        const projectNameValidator = fieldsProps().project_name.validators[0];

        // Test empty value
        expect(projectNameValidator('')).toBe('Project name is required.');

        // Test with value
        expect(projectNameValidator('My Test Project')).toBe('');
      });
    });
  });

  describe('country and state field behavior', () => {
    it('shows and hides state field based on selected country', async () => {
      wrapper = await createComponent();
      await nextTick();

      const countrySelect = findCountrySelect();

      await countrySelect.vm.$emit('input', 'NL');
      await nextTick();
      expect(fieldsProps()).not.toHaveProperty('state');

      await countrySelect.vm.$emit('input', COUNTRY_WITH_STATES);
      await nextTick();
      expect(fieldsProps()).toHaveProperty('state');
    });

    it.each`
      selectedCountry        | selectedState | stateFieldExists | result
      ${COUNTRY_WITH_STATES} | ${null}       | ${true}          | ${'State or province is required.'}
      ${'NL'}                | ${null}       | ${false}         | ${''}
      ${COUNTRY_WITH_STATES} | ${STATE}      | ${true}          | ${''}
    `(
      'validates state with selectedCountry=$selectedCountry and selectedState=$selectedState',
      async ({ selectedCountry, selectedState, stateFieldExists, result }) => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: selectedCountry, state: selectedState },
        });

        const hasStateField = 'state' in fieldsProps();
        expect(hasStateField).toBe(stateFieldExists);

        if (hasStateField) {
          const stateValidator = fieldsProps().state.validators[0];
          expect(stateValidator(selectedState)).toBe(result);
        }
      },
    );

    it.each`
      countryValue | result
      ${''}        | ${'Country or region is required.'}
      ${null}      | ${'Country or region is required.'}
      ${'US'}      | ${''}
      ${'NL'}      | ${''}
    `('validates country with value=$countryValue', async ({ countryValue, result }) => {
      wrapper = await createComponent({
        userData: { ...defaultUserData, country: countryValue },
      });

      const countryValidator = fieldsProps().country.validators[0];
      expect(countryValidator(countryValue)).toBe(result);
    });
  });

  describe('submitting', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
      await nextTick();
    });

    it('tracks the trial form submission and submits the form', async () => {
      const submitSpy = jest.fn();
      const formElement = wrapper.vm.$refs.form.$el;
      formElement.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(trackSaasTrialLeadSubmit).toHaveBeenCalledWith(
        gtmSubmitEventLabel,
        defaultUserData.emailDomain,
      );
      expect(submitSpy).toHaveBeenCalled();
    });
  });
});
