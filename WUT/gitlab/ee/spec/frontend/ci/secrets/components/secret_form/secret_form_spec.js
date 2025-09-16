import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import {
  GlCollapsibleListbox,
  GlDatepicker,
  GlFormInput,
  GlFormTextarea,
  GlModal,
  GlSprintf,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import createRouter from 'ee/ci/secrets/router';
import SecretBranchesField from 'ee/ci/secrets/components/secret_form/secret_branches_field.vue';
import createSecretMutation from 'ee/ci/secrets/graphql/mutations/create_secret.mutation.graphql';
import updateSecretMutation from 'ee/ci/secrets/graphql/mutations/update_secret.mutation.graphql';
import getProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import { DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { mockProjectBranches, mockProjectSecret, mockProjectUpdateSecret } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);
Vue.use(VueRouter);

describe('SecretForm component', () => {
  let wrapper;
  let mockApollo;
  let mockCreateSecretResponse;
  let mockUpdateSecretResponse;
  let mockProjectBranchesResponse;
  const router = createRouter('/', {});

  const defaultProps = {
    areEnvironmentsLoading: false,
    environments: ['production', 'development'],
    fullPath: 'path/to/project',
    isEditing: false,
    submitButtonText: 'Add secret',
  };

  const findAddCronButton = () => wrapper.findByTestId('add-custom-rotation-button');
  const findCronField = () => wrapper.findByTestId('secret-cron');
  const findConfirmEditModal = () => wrapper.findComponent(GlModal);
  const findBranchField = () => wrapper.findComponent(SecretBranchesField);
  const findDescriptionField = () => wrapper.findByTestId('secret-description');
  const findDescriptionFieldGroup = () => wrapper.findByTestId('secret-description-field-group');
  const findEditValueButton = () => wrapper.findByTestId('edit-value-button');
  const findExpirationField = () => wrapper.findComponent(GlDatepicker);
  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findNameFieldGroup = () => wrapper.findByTestId('secret-name-field-group');
  const findNameField = () => findNameFieldGroup().findComponent(GlFormInput);
  const findRotationPeriodField = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueFieldGroup = () => wrapper.findByTestId('secret-value-field-group');
  const findValueField = () => findValueFieldGroup().findComponent(GlFormTextarea);
  const findSubmitButton = () => wrapper.findByTestId('submit-form-button');

  const createComponent = ({ props, mountFn = shallowMountExtended, stubs } = {}) => {
    const handlers = [
      [createSecretMutation, mockCreateSecretResponse],
      [updateSecretMutation, mockUpdateSecretResponse],
      [getProjectBranches, mockProjectBranchesResponse],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretForm, {
      router,
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
        ...stubs,
      },
    });
  };

  const today = new Date();

  const inputRequiredFields = async () => {
    findNameField().vm.$emit('input', 'SECRET_KEY');
    findValueField().vm.$emit('input', 'SECRET_VALUE');
    findDescriptionField().vm.$emit('input', 'This is a secret');
    findBranchField().vm.$emit('select-branch', 'main');
    findEnvironmentsDropdown().vm.$emit('select-environment', '*');

    await nextTick();
  };

  beforeEach(() => {
    mockCreateSecretResponse = jest.fn();
    mockUpdateSecretResponse = jest.fn();
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
  });

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all fields', () => {
      expect(findBranchField().exists()).toBe(true);
      expect(findDescriptionField().exists()).toBe(true);
      expect(findExpirationField().exists()).toBe(true);
      expect(findEnvironmentsDropdown().exists()).toBe(true);
      expect(findNameField().exists()).toBe(true);
      expect(findRotationPeriodField().exists()).toBe(true);

      expect(findValueField().exists()).toBe(true);
      expect(findValueField().attributes('placeholder')).toBe('Enter a value for the secret');
      expect(findValueField().attributes('disabled')).toBeUndefined();
    });

    it('sets expiration date in the future', () => {
      const expirationMinDate = findExpirationField().props('minDate').getTime();
      expect(expirationMinDate).toBeGreaterThan(today.getTime());
    });

    it('does not show the confirmation modal', () => {
      expect(findConfirmEditModal().props('visible')).toBe(false);
    });
  });

  describe('environment dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { CiEnvironmentsDropdown } });
    });

    it('sets the environment', async () => {
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('');

      findEnvironmentsDropdown().vm.$emit('select-environment', 'staging');
      await nextTick();

      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('staging');
    });

    it('bubbles up the search event', async () => {
      findEnvironmentsDropdown().vm.$emit('search-environment-scope', 'dev');
      await nextTick();

      expect(wrapper.emitted('search-environment')).toEqual([['dev']]);
    });
  });

  describe('branch dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { SecretBranchesField } });
    });

    it('sets the branch', async () => {
      expect(findBranchField().props('selectedBranch')).toBe('');

      findBranchField().vm.$emit('select-branch', 'main');
      await nextTick();

      expect(findBranchField().props('selectedBranch')).toBe('main');
    });
  });

  describe('rotation period field', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows default toggle text', () => {
      expect(findRotationPeriodField().props('toggleText')).toBe('Select a reminder interval');
    });

    it('can select predefined rotation periods and renders the correct toggle text', async () => {
      findRotationPeriodField().vm.$emit('click');
      findRotationPeriodField().vm.$emit('select', '14');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('Every 2 weeks');
    });

    it('can set custom cron', async () => {
      findRotationPeriodField().vm.$emit('click');
      findCronField().vm.$emit('input', '0 6 * * *');
      findAddCronButton().vm.$emit('click');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('0 6 * * *');
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates name field', async () => {
      expect(findNameField().attributes('state')).toBe('true');

      findNameField().vm.$emit('input', '');
      await nextTick();

      expect(findNameField().attributes('state')).toBeUndefined();
      expect(findNameFieldGroup().attributes('invalid-feedback')).toBe('This field is required.');

      findNameField().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findNameField().attributes('state')).toBe('true');
    });

    it('validates value field', async () => {
      expect(findValueField().attributes('state')).toBe('true');

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueField().attributes('state')).toBeUndefined();
      expect(findValueFieldGroup().attributes('invalid-feedback')).toBe('This field is required.');

      findValueField().vm.$emit('input', 'SECRET_VALUE');
      await nextTick();

      expect(findValueField().attributes('state')).toBe('true');
    });

    it('validates description field', async () => {
      expect(findDescriptionField().attributes('state')).toBe('true');

      // string must be <= SECRET_DESCRIPTION_MAX_LENGTH (200) characters
      findDescriptionField().vm.$emit(
        'input',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
      );
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBeUndefined();
      expect(findDescriptionFieldGroup().attributes('invalid-feedback')).toBe(
        'This field is required and must be 200 characters or less.',
      );

      findDescriptionField().vm.$emit('input', 'This is a short description of the secret.');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBe('true');

      // description cannot be empty
      findDescriptionField().vm.$emit('input', '');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBeUndefined();
    });

    it('submit button is enabled when required fields have input', async () => {
      expect(findSubmitButton().props('disabled')).toBe(true);

      await inputRequiredFields();
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });
  });

  describe('creating a new secret', () => {
    const createSecret = async () => {
      await inputRequiredFields();

      findSubmitButton().vm.$emit('click');
    };

    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the correct text for submit button', () => {
      expect(findSubmitButton().text()).toBe('Add secret');
    });

    it('renders loading icon while submitting', async () => {
      expect(findSubmitButton().props('loading')).toBe(false);

      await createSecret();
      await nextTick();

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(mockProjectSecret());
        createComponent({ mountFn: mountExtended });
      });

      it('calls the create mutation with the correct variables', async () => {
        await createSecret();
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockCreateSecretResponse).toHaveBeenCalledWith({
          branch: 'main',
          description: 'This is a secret',
          environment: '*',
          name: 'SECRET_KEY',
          projectPath: 'path/to/project',
          rotationPeriod: '',
          secret: 'SECRET_VALUE',
        });
      });

      it('redirects to the secret details page', async () => {
        const routerPushSpy = jest
          .spyOn(router, 'push')
          .mockImplementation(() => Promise.resolve());
        await createSecret();
        await waitForPromises();

        expect(routerPushSpy).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: 'SECRET_KEY' },
        });
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(
          mockProjectSecret({ errors: ['This secret is invalid.'] }),
        );
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        await createSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({ message: 'This secret is invalid.' });
      });
    });

    describe('when submission fails', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockRejectedValue(new Error());
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        await createSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong on our end. Please try again.',
        });
      });
    });
  });

  describe('editing a secret', () => {
    beforeEach(async () => {
      createComponent({
        mountFn: mountExtended,
        props: {
          isEditing: true,
          secretData: {
            branch: 'feat-1',
            description: 'This is a secret',
            environment: 'production',
            name: 'PROD_PWD',
          },
        },
      });

      await nextTick();
    });

    it('does not render name field', () => {
      expect(findNameFieldGroup().exists()).toBe(false);
    });

    it('loads fetched secret data', () => {
      expect(findBranchField().props('selectedBranch')).toBe('feat-1');
      expect(findDescriptionField().props('value')).toBe('This is a secret');
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('production');
    });

    it('disables value field', () => {
      expect(findValueField().attributes('placeholder')).toBe('* * * * * * *');
      expect(findValueField().attributes('disabled')).toBeDefined();
    });

    it('enables and focuses on value field when "Edit value" button is clicked', async () => {
      const focusSpy = jest.spyOn(findValueField().element, 'focus');

      expect(findValueField().attributes('disabled')).toBeDefined();

      findEditValueButton().vm.$emit('click');
      await nextTick();

      expect(findValueField().attributes('disabled')).toBeUndefined();
      expect(focusSpy).toHaveBeenCalled();
    });

    it('disables value field again when it is out of focus', async () => {
      findEditValueButton().vm.$emit('click');
      await nextTick();

      expect(findValueField().attributes('disabled')).toBeUndefined();

      findValueField().vm.$emit('blur');
      await nextTick();

      expect(findValueField().attributes('disabled')).toBeDefined();
    });

    it('allows value field to be empty', async () => {
      expect(findValueFieldGroup().attributes('state')).toBeUndefined();

      findEditValueButton().vm.$emit('click');
      findValueField().vm.$emit('input', 'EDITED_SECRET_VALUE');
      await nextTick();

      expect(findValueFieldGroup().attributes('state')).toBeUndefined();

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueFieldGroup().attributes('state')).toBeUndefined();
    });

    it('renders the correct text for submit button', () => {
      expect(findSubmitButton().text()).toBe('Save changes');
    });

    it('submit button is already enabled', () => {
      expect(findSubmitButton().props('disabled')).toBe(false);
    });

    it('opens confirmation modal when submitting', async () => {
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmEditModal().text()).toContain(
        'Are you sure you want to update secret PROD_PWD?',
      );
      expect(findConfirmEditModal().props('visible')).toBe(true);
    });

    it.each`
      modalEvent
      ${'canceled'}
      ${'hidden'}
      ${'secondary'}
    `('hides modal when $modalEvent event is triggered', async ({ modalEvent }) => {
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmEditModal().props('visible')).toBe(true);

      findConfirmEditModal().vm.$emit(modalEvent);
      await nextTick();

      expect(findConfirmEditModal().props('visible')).toBe(false);
    });

    const editSecret = async ({ finishRequest = true, editValue = true } = {}) => {
      if (editValue) {
        findEditValueButton().vm.$emit('click');
        findValueField().vm.$emit('input', 'EDITED_SECRET_VALUE');
      }

      findDescriptionField().vm.$emit('input', 'This is an edited secret');
      findBranchField().vm.$emit('select-branch', 'edit-branch');
      findEnvironmentsDropdown().vm.$emit('select-environment', 'edit-env');
      await nextTick();

      findSubmitButton().vm.$emit('click');
      await nextTick();

      findConfirmEditModal().vm.$emit('primary', { preventDefault: jest.fn() });

      if (finishRequest) {
        await waitForPromises();
      }
      await nextTick();
    };

    describe('when submitting form', () => {
      it('hides confirmation modal', async () => {
        await editSecret();

        expect(findConfirmEditModal().props('visible')).toBe(false);
      });

      it('renders loading icon while submitting', async () => {
        await editSecret({ finishRequest: false });

        expect(findSubmitButton().props('loading')).toBe(true);
      });
    });

    describe('when update is successful', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockResolvedValue(
          mockProjectUpdateSecret({
            branch: 'edit-branch',
            description: 'This is an edited secret',
            environment: 'edit-env',
            name: 'PROD_PWD',
            secret: 'EDITED_SECRET_VALUE',
          }),
        );
      });

      it('calls the create mutation with the correct variables', async () => {
        await editSecret();

        expect(mockUpdateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockUpdateSecretResponse).toHaveBeenCalledWith({
          branch: 'edit-branch',
          description: 'This is an edited secret',
          environment: 'edit-env',
          expiration: undefined,
          name: 'PROD_PWD',
          projectPath: 'path/to/project',
          rotationPeriod: '',
          secret: 'EDITED_SECRET_VALUE',
        });
      });

      it('leaves value blank when it is not edited', async () => {
        await editSecret({ editValue: false });

        expect(mockUpdateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockUpdateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({ secret: undefined }),
        );
      });

      it('triggers toast message', async () => {
        await editSecret();

        expect(wrapper.emitted('show-secrets-toast')).toEqual([
          ['Secret PROD_PWD was successfully updated.'],
        ]);
      });

      it('redirects to the secret details page', async () => {
        const routerPushSpy = jest
          .spyOn(router, 'push')
          .mockImplementation(() => Promise.resolve());
        await editSecret();

        expect(routerPushSpy).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: 'PROD_PWD' },
        });
      });
    });

    describe('when update returns errors', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockResolvedValue(
          mockProjectUpdateSecret({ errors: ['Cannot update secret.'] }),
        );
      });

      it('renders error message from API', async () => {
        await editSecret();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({ message: 'Cannot update secret.' });
      });
    });

    describe('when update fails', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockRejectedValue(new Error());
      });

      it('renders error message', async () => {
        await editSecret();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong on our end. Please try again.',
        });
      });
    });
  });
});
