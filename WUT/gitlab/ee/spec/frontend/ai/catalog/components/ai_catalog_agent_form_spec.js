import { GlFormFields } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';

describe('AiCatalogAgentForm', () => {
  let wrapper;

  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findProjectIdField = () => wrapper.findByTestId('agent-form-input-project-id');
  const findNameField = () => wrapper.findByTestId('agent-form-input-name');
  const findDescriptionField = () => wrapper.findByTestId('agent-form-textarea-description');
  const findSystemPromptField = () => wrapper.findByTestId('agent-form-textarea-system-prompt');
  const findUserPromptField = () => wrapper.findByTestId('agent-form-textarea-user-prompt');
  const findSubmitButton = () => wrapper.findByTestId('agent-form-submit-button');

  const defaultProps = {
    mode: 'create',
    isLoading: false,
  };

  const defaultFormValues = {
    projectId: 'gid://gitlab/Project/1000000',
    name: 'My AI Agent',
    description: 'A helpful AI assistant',
    systemPrompt: 'You are a helpful assistant',
    userPrompt: 'Help me with coding',
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormFields,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      const initialProps = {
        ...defaultFormValues,
        mode: 'edit',
      };

      createWrapper(initialProps);

      expect(findProjectIdField().props('value')).toBe(defaultFormValues.projectId);
      expect(findNameField().props('value')).toBe(defaultFormValues.name);
      expect(findDescriptionField().props('value')).toBe(defaultFormValues.description);
      expect(findSystemPromptField().props('value')).toBe(defaultFormValues.systemPrompt);
      expect(findUserPromptField().props('value')).toBe(defaultFormValues.userPrompt);
    });

    it('renders the form with empty values (except tmp project ID) when no props are provided', () => {
      createWrapper();

      expect(findProjectIdField().props('value')).toBe('gid://gitlab/Project/1000000');
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findSystemPromptField().props('value')).toBe('');
      expect(findUserPromptField().props('value')).toBe('');
    });
  });

  describe('Loading Prop', () => {
    it('shows button with loading icon when the loading property is true', () => {
      createWrapper({ isLoading: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('does not show the button with loading icon when the loading property is false', () => {
      createWrapper({ isLoading: false });

      expect(findSubmitButton().props('loading')).toBe(false);
    });
  });

  describe('Form Submission', () => {
    it('emits form values when user clicks submit', async () => {
      const initialProps = {
        ...defaultFormValues,
        mode: 'edit',
      };

      createWrapper(initialProps);

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[defaultFormValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        projectId: addRandomSpacesToString(defaultFormValues.projectId),
        name: addRandomSpacesToString(defaultFormValues.name),
        description: addRandomSpacesToString(defaultFormValues.description),
        systemPrompt: addRandomSpacesToString(defaultFormValues.systemPrompt),
        userPrompt: addRandomSpacesToString(defaultFormValues.userPrompt),
      };

      createWrapper(formValuesWithRandomSpaces);

      await findFormFields().vm.$emit('submit');

      expect(wrapper.emitted('submit')).toEqual([[defaultFormValues]]);
    });
  });
});
