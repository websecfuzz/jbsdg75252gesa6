import { nextTick } from 'vue';
import { GlButton, GlFormGroup, GlFormInput } from '@gitlab/ui';
import StatusChecksForm from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(StatusChecksForm, {
      propsData,
      stubs: {
        GlButton,
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
        GlFormInput: stubComponent(GlFormInput, {
          props: ['state', 'disabled', 'value'],
          template: `<input />`,
        }),
      },
    });
  };
  const findNameInput = () => wrapper.findByTestId('service-name-input');
  const findNameValidation = () => wrapper.findByTestId('service-name-group');
  const findSaveChangesButton = () => wrapper.findByTestId('save-btn');
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findUrlInput = () => wrapper.findByTestId('api-url-input');
  const findUrlValidation = () => wrapper.findByTestId('api-url-group');
  const findValidations = () => [findNameValidation(), findUrlValidation()];
  const inputsAreValid = () => findValidations().every((x) => x.props('state'));

  describe('initialization', () => {
    it('shows empty inputs when no initial data is given', () => {
      createComponent({ selectedStatusCheck: null });
      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe('');
      expect(findUrlInput().props('value')).toBe('');
    });
    it('shows filled inputs when initial data is given', () => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[0] });
      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe(statusChecksRulesMock[0].name);
      expect(findUrlInput().props('value')).toBe(statusChecksRulesMock[0].externalUrl);
    });
  });

  describe('emits events', () => {
    beforeEach(() => {
      createComponent({ selectedStatusCheck: statusChecksRulesMock[0] });
    });
    it('emits save event when save button is clicked', () => {
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
          },
        ],
      ]);
    });
    it('emits close event when cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(wrapper.emitted('close-status-check-drawer')).toEqual([[]]);
    });
  });

  describe('validations', () => {
    it('shows the validation messages if invalid on submission', async () => {
      createComponent({
        selectedStatusCheck: null,
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toBe(undefined);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Please provide a name.');
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it('shows the invalid URL error if the URL is invalid', async () => {
      createComponent({ selectedStatusCheck: { name: 'QA', externalUrl: 'not//valid-utl' } });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toBe(undefined);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it('shows the serverValidationErrors if given', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
        serverValidationErrors: [
          'External url has already been taken',
          'Name has already been taken',
        ],
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
          },
        ],
      ]);
      await nextTick();
      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Name already exists.');
      expect(findUrlValidation().props('invalidFeedback')).toBe('External API is already in use.');
    });

    it('does not show any errors if the values are valid', async () => {
      createComponent({
        selectedStatusCheck: statusChecksRulesMock[0],
      });
      findSaveChangesButton().vm.$emit('click', {
        preventDefault: jest.fn(),
      });
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [
          {
            id: statusChecksRulesMock[0].id,
            name: statusChecksRulesMock[0].name,
            externalUrl: statusChecksRulesMock[0].externalUrl,
          },
        ],
      ]);
      await nextTick();
      expect(inputsAreValid()).toBe(true);
    });
  });
});
