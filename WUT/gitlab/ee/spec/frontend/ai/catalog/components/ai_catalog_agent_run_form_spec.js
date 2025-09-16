import { GlForm, GlFormFields } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';

describe('AiCatalogAgentRunForm', () => {
  let wrapper;

  const mockUserPrompt = 'Mock user prompt';

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findUserPromptField = () => wrapper.findByTestId('agent-run-form-user-prompt');
  const findSubmitButton = () => wrapper.findByTestId('agent-run-form-submit-button');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentRunForm, {
      propsData: {
        ...props,
      },
      stubs: {
        GlFormFields,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders form with submit button', () => {
    expect(findForm().exists()).toBe(true);
    expect(findSubmitButton().text()).toBe('Run (Coming soon)');
  });

  it('renders form fields', () => {
    expect(findFormFields().props('fields')).toEqual({
      userPrompt: expect.any(Object),
    });
    expect(findFormFields().props('values')).toEqual({
      userPrompt: '',
    });
  });

  it('renders form fields with correct initial values', () => {
    createComponent({
      props: { defaultUserPrompt: mockUserPrompt },
    });

    expect(findFormFields().props('values').userPrompt).toBe(mockUserPrompt);
  });

  describe('form submission', () => {
    it('emits form values on form submit', () => {
      findUserPromptField().vm.$emit('update', mockUserPrompt);
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(wrapper.emitted('submit')[0]).toEqual([{ userPrompt: mockUserPrompt }]);
    });

    it('renders submit button as loading', async () => {
      createComponent();

      expect(findSubmitButton().props('loading')).toBe(false);

      await wrapper.setProps({ isSubmitting: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });
  });
});
