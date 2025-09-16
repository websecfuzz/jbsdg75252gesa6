import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlForm } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SelfHostedModelForm from 'ee/ai/duo_self_hosted/self_hosted_models/components/self_hosted_model_form.vue';
import TestConnectionButton from 'ee/ai/duo_self_hosted/self_hosted_models/components/test_connection_button.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import InputCopyToggleVisibility from '~/vue_shared/components/input_copy_toggle_visibility/input_copy_toggle_visibility.vue';
import createSelfHostedModelMutation from 'ee/ai/duo_self_hosted/self_hosted_models/graphql/mutations/create_self_hosted_model.mutation.graphql';
import updateSelfHostedModelMutation from 'ee/ai/duo_self_hosted/self_hosted_models/graphql/mutations/update_self_hosted_model.mutation.graphql';
import { createAlert } from '~/alert';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import {
  SELF_HOSTED_MODEL_MUTATIONS,
  BEDROCK_DUMMY_ENDPOINT,
} from 'ee/ai/duo_self_hosted/self_hosted_models/constants';
import {
  SELF_HOSTED_MODEL_OPTIONS,
  mockSelfHostedModel as mockModelData,
  mockBedrockSelfHostedModel,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility');

describe('SelfHostedModelForm', () => {
  let wrapper;

  const basePath = '/admin/ai/duo_self_hosted';
  const duoConfigurationSettingsPath = '/admin/gitlab_duo/configuration';
  const createMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelCreate: {
        errors: [],
      },
    },
  });

  const createComponent = async ({
    props = {
      mutationData: {
        name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
        mutation: createSelfHostedModelMutation,
      },
    },
    apolloHandlers = [[createSelfHostedModelMutation, createMutationSuccessHandler]],
    injectedProps = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = mountExtended(SelfHostedModelForm, {
      attachTo: document.body,
      apolloProvider: mockApollo,
      provide: {
        basePath,
        betaModelsEnabled: true,
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
        duoConfigurationSettingsPath,
        ...injectedProps,
      },
      propsData: {
        ...props,
      },
    });

    await waitForPromises();
  };

  beforeEach(async () => {
    await createComponent({
      props: {
        mutationData: {
          name: SELF_HOSTED_MODEL_MUTATIONS.CREATE,
          mutation: createSelfHostedModelMutation,
        },
      },
    });
  });

  // Find elements
  const findGlForm = () => wrapper.findComponent(GlForm);
  const findNameInputField = () => wrapper.findByLabelText('Deployment name', { exact: false });
  const findEndpointInputField = () => wrapper.findByLabelText('Endpoint', { exact: false });
  const findPlatformDropdownSelector = () => wrapper.findByTestId('platform-dropdown-selector');
  const findIdentifierInputField = () =>
    wrapper.findByLabelText('Model identifier', { exact: false });
  const findApiKeyInputField = () => wrapper.findComponent(InputCopyToggleVisibility);
  const findModelDropDownSelector = () => wrapper.findComponent(ModelSelectDropdown);
  const findCreateButton = () => wrapper.find('button[type="submit"]');
  const findCancelButton = () => wrapper.findByText('Cancel');
  const findTestConnectionButton = () => wrapper.findComponent(TestConnectionButton);
  const findBetaAlert = () => wrapper.findComponent(GlAlert);
  const findDuoConfigurationLink = () => wrapper.findByTestId('duo-configuration-link');
  const findIdentifierInput = () => wrapper.findByLabelText('Model identifier', { exact: false });
  const findIdentifierLabelDescription = () =>
    wrapper.findByText(/Provide the model identifier/, { exact: false });

  // Find validation messages
  const findNameValidationMessage = () => wrapper.findByText('Please enter a deployment name.');
  const findModelValidationMessage = () => wrapper.findByText('Please select a model.');
  const findEndpointValidationMessage = () => wrapper.findByText('Please enter an endpoint.');
  const findIdentifierValidationMessage = () =>
    wrapper.findByText('Please enter a model identifier.');
  const findIdentifierTooLongValidationMessage = () =>
    wrapper.findByText('Model identifier must be less than 255 characters.');
  const findBedrockIdentifierValidationMessage = () =>
    wrapper.findByText('Model identifier must start with "bedrock/"');

  it('renders the self-hosted model form', () => {
    expect(findGlForm().exists()).toBe(true);
  });

  describe('when beta models are enabled', () => {
    it('does not display a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(false);
    });
  });

  describe('when beta models are disabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { betaModelsEnabled: false } });
    });

    it('displays a beta models info alert', () => {
      expect(findBetaAlert().text()).toMatch('More models are available in beta.');
      expect(findDuoConfigurationLink().attributes('href')).toBe(duoConfigurationSettingsPath);
    });
  });

  describe('form fields', () => {
    describe('for all platforms', () => {
      it('renders the name input field', () => {
        expect(findNameInputField().exists()).toBe(true);
      });

      it('renders the platform select dropdown', () => {
        expect(findPlatformDropdownSelector().exists()).toBe(true);
      });

      describe('model select dropdown', () => {
        it('renders the model select dropdown', () => {
          expect(findModelDropDownSelector().exists()).toBe(true);
          expect(findModelDropDownSelector().props('placeholderDropdownText')).toEqual(
            'Select model',
          );
        });

        it('passes it model options sorted by release state', () => {
          const modelOptions = findModelDropDownSelector().props('items');

          expect(modelOptions.map(({ text, releaseState }) => [text, releaseState])).toEqual([
            ['Codestral', 'GA'],
            ['Mistral', 'GA'],
            ['GPT', 'GA'],
            ['Claude 3', 'GA'],
            ['CodeGemma', 'BETA'],
            ['Code-Llama', 'BETA'],
            ['Deepseek Coder', 'BETA'],
            ['Llama 3', 'BETA'],
          ]);
        });
      });
    });

    describe('API platform', () => {
      it('renders the endpoint input field', () => {
        expect(findEndpointInputField().exists()).toBe(true);
      });

      it('renders the optional API token input field', () => {
        expect(findApiKeyInputField().exists()).toBe(true);
      });

      describe('identifier placeholder', () => {
        it('shows custom_openai/ placeholder for non-cloud provider models', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');

          expect(findIdentifierInput().attributes('placeholder')).toBe('custom_openai/');
        });

        it('shows no placeholder for cloud provider models', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'GPT');

          expect(findIdentifierInput().attributes('placeholder')).toBe('');

          await findModelDropDownSelector().vm.$emit('select', 'CLAUDE_3');

          expect(findIdentifierInput().attributes('placeholder')).toBe('');
        });
      });

      describe('identifier label description', () => {
        it('shows custom_openai/ format for non-cloud provider models', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');

          expect(findIdentifierLabelDescription().text()).toContain('custom_openai/model-name');
        });

        it('shows provider/ format for cloud provider models', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'GPT');

          expect(findIdentifierLabelDescription().text()).toContain('provider/model-name');

          await findModelDropDownSelector().vm.$emit('select', 'CLAUDE_3');

          expect(findIdentifierLabelDescription().text()).toContain('provider/model-name');
        });
      });
    });

    describe('Bedrock platform', () => {
      beforeEach(() => {
        findPlatformDropdownSelector().vm.$emit('select', 'bedrock');
      });

      it('does not render the endpoint input field', () => {
        expect(findEndpointInputField().exists()).toBe(false);
      });

      it('does not render the API token input field', () => {
        expect(findApiKeyInputField().exists()).toBe(false);
      });

      it('renders aws setup message', () => {
        expect(findGlForm().text()).toMatch(
          'To fully set up AWS credentials for this model please refer to the AWS Bedrock Configuration Guide',
        );
      });

      describe('identifier placeholder', () => {
        it('always shows bedrock/ placeholder regardless of model', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
          expect(findIdentifierInput().attributes('placeholder')).toBe('bedrock/');

          await findModelDropDownSelector().vm.$emit('select', 'GPT');
          expect(findIdentifierInput().attributes('placeholder')).toBe('bedrock/');
        });
      });

      describe('identifier label description', () => {
        it('shows bedrock/ format regardless of model', async () => {
          await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
          expect(findIdentifierLabelDescription().text()).toContain('bedrock/model-name');

          await findModelDropDownSelector().vm.$emit('select', 'GPT');
          expect(findIdentifierLabelDescription().text()).toContain('bedrock/model-name');
        });
      });
    });
  });

  describe('form validations', () => {
    describe('API platform', () => {
      it('displays validation errors when required fields are empty', async () => {
        await findGlForm().trigger('submit');

        expect(findNameValidationMessage().exists()).toBe(true);
        expect(findModelValidationMessage().exists()).toBe(true);
        expect(findEndpointValidationMessage().exists()).toBe(true);
        expect(findIdentifierValidationMessage().exists()).toBe(true);
      });

      it('displays validation error when identifier is too long', async () => {
        const longModelIdentifier = `identifier/${'looooong-identifier'.repeat(255)}`;
        await findIdentifierInputField().setValue(longModelIdentifier);
        await findGlForm().trigger('submit');

        expect(findIdentifierTooLongValidationMessage().exists()).toBe(true);
      });
    });

    describe('Bedrock platform', () => {
      beforeEach(() => {
        findPlatformDropdownSelector().vm.$emit('select', 'bedrock');
      });

      it('displays validation errors when required fields are empty', async () => {
        await findGlForm().trigger('submit');

        expect(findNameValidationMessage().exists()).toBe(true);
        expect(findModelValidationMessage().exists()).toBe(true);
        expect(findIdentifierValidationMessage().exists()).toBe(true);
      });

      it('displays validation error for invalid identifier', async () => {
        await findIdentifierInputField().setValue('invalid/identifier');
        await findGlForm().trigger('submit');

        expect(findBedrockIdentifierValidationMessage().exists()).toBe(true);
      });

      it('displays validation error when identifier is too long', async () => {
        const longModelIdentifier = `bedrock/${'looooong-identifier'.repeat(255)}`;
        await findIdentifierInputField().setValue(longModelIdentifier);
        await findGlForm().trigger('submit');

        expect(findIdentifierTooLongValidationMessage().exists()).toBe(true);
      });
    });
  });

  describe('test connection button', () => {
    it('renders the button', () => {
      expect(findTestConnectionButton().exists()).toBe(true);
    });

    it('passes the correct props', async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
      await findIdentifierInputField().setValue('identifier/test');
      await findApiKeyInputField().vm.$emit('input', 'test-abc-123');

      expect(findTestConnectionButton().props()).toEqual({
        connectionTestInput: {
          name: 'test deployment',
          model: 'MISTRAL',
          endpoint: 'http://test.com',
          identifier: 'identifier/test',
          apiToken: 'test-abc-123',
        },
        disabled: false,
      });
    });

    it('is disabled when there are missing inputs', () => {
      expect(findTestConnectionButton().props('disabled')).toBe(true);
    });
  });

  it('renders a cancel button', () => {
    expect(findCancelButton().exists()).toBe(true);
  });

  describe('when required form inputs are missing', () => {
    it('does not invoke mutation', async () => {
      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(createMutationSuccessHandler).not.toHaveBeenCalled();
    });
  });

  describe('server errors', () => {
    describe('when deployment name is not unique', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: ['Validation failed: Name has already been taken'],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please enter a unique deployment name.');
      });
    });

    describe('when endpoint is not valid', () => {
      const createMutationValidationErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiSelfHostedModelCreate: {
            errors: [
              'Validation failed: Endpoint is blocked: Only allowed schemes are http, https',
            ],
          },
        },
      });
      const apolloHandlers = [
        [createSelfHostedModelMutation, createMutationValidationErrorHandler],
      ];

      beforeEach(async () => {
        await createComponent({ apolloHandlers });
      });

      it('renders an error message', async () => {
        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('invalid endpoint');
        await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(wrapper.text()).toMatch('Please add a valid endpoint.');
      });
    });

    describe('when the error is not specific', () => {
      it('displays a generic error alert', async () => {
        const error = new Error();
        const createMutationErrorHandler = jest.fn().mockRejectedValue(error);

        await createComponent({
          apolloHandlers: [[createSelfHostedModelMutation, createMutationErrorHandler]],
        });

        await findNameInputField().setValue('test deployment');
        await findEndpointInputField().setValue('http://test.com');
        await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
        await findIdentifierInputField().setValue('provider/model-name');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'There was an error saving the self-hosted model. Please try again.',
            error,
            captureError: true,
          }),
        );
      });
    });
  });

  describe('When creating a self-hosted model', () => {
    beforeEach(async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
      await findIdentifierInputField().setValue('provider/model-name');

      wrapper.find('form').trigger('submit.prevent');
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Create self-hosted model');
    });

    it('invokes the create mutation with correct input variables', async () => {
      await waitForPromises();

      expect(createMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          name: 'test deployment',
          endpoint: 'http://test.com',
          model: 'MISTRAL',
          apiToken: '',
          identifier: 'provider/model-name',
        },
      });
    });

    it('displays success message when model successfully created', async () => {
      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
        expect.objectContaining({
          message: 'The self-hosted model was successfully created.',
          variant: 'success',
        }),
      ]);
    });

    describe('bedrock models', () => {
      it('invokes the create mutation with correct input variables', async () => {
        await findPlatformDropdownSelector().vm.$emit('select', 'bedrock');
        await findIdentifierInputField().setValue('bedrock/example-model');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(createMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            name: 'test deployment',
            endpoint: BEDROCK_DUMMY_ENDPOINT,
            model: 'MISTRAL',
            apiToken: '',
            identifier: 'bedrock/example-model',
          },
        });
      });
    });
  });

  describe('When editing a self-hosted model', () => {
    const updateMutationSuccessHandler = jest.fn().mockResolvedValue({
      data: {
        aiSelfHostedModelUpdate: {
          errors: [],
        },
      },
    });

    beforeEach(async () => {
      await createComponent({
        props: {
          initialFormValues: mockModelData,
          mutationData: {
            name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
            mutation: updateSelfHostedModelMutation,
          },
          submitButtonText: 'Save changes',
        },
        apolloHandlers: [[updateSelfHostedModelMutation, updateMutationSuccessHandler]],
      });
    });

    it('renders the submit button with the correct text', () => {
      const button = findCreateButton();

      expect(button.text()).toBe('Save changes');
    });

    it('renders the model dropdown with initial model', () => {
      expect(findModelDropDownSelector().props('selectedOption')).toStrictEqual({
        text: 'Mistral',
        value: 'MISTRAL',
        releaseState: 'GA',
      });
    });

    it('invokes the update mutation with correct input variables', async () => {
      await findNameInputField().setValue('test deployment');
      await findEndpointInputField().setValue('http://test.com');
      await findModelDropDownSelector().vm.$emit('select', 'MISTRAL');
      await findApiKeyInputField().vm.$emit('input', 'abc123');
      await findIdentifierInputField().setValue('provider/model-name');

      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: mockModelData.id,
          name: 'test deployment',
          endpoint: 'http://test.com',
          model: 'MISTRAL',
          apiToken: 'abc123',
          identifier: 'provider/model-name',
        },
      });
    });

    it('displays success message when model successfully saved', async () => {
      await findNameInputField().setValue('test deployment');
      wrapper.find('form').trigger('submit.prevent');

      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(basePath, [
        expect.objectContaining({
          message: 'The self-hosted model was successfully saved.',
          variant: 'success',
        }),
      ]);
    });

    describe('bedrock models', () => {
      beforeEach(async () => {
        await createComponent({
          props: {
            initialFormValues: mockBedrockSelfHostedModel,
            mutationData: {
              name: SELF_HOSTED_MODEL_MUTATIONS.UPDATE,
              mutation: updateSelfHostedModelMutation,
            },
            submitButtonText: 'Edit self-hosted model',
          },
          apolloHandlers: [[updateSelfHostedModelMutation, updateMutationSuccessHandler]],
        });
      });

      it('invokes the update mutation with correct input variables', async () => {
        await findIdentifierInputField().setValue('bedrock/new-example-model');

        wrapper.find('form').trigger('submit.prevent');

        await waitForPromises();

        expect(updateMutationSuccessHandler).toHaveBeenCalledWith({
          input: {
            id: mockBedrockSelfHostedModel.id,
            name: 'mock-bedrock-model',
            endpoint: BEDROCK_DUMMY_ENDPOINT,
            model: 'MISTRAL',
            apiToken: '',
            identifier: 'bedrock/new-example-model',
          },
        });
      });
    });
  });
});
