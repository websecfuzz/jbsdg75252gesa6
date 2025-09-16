import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import DuoWorkflowSettingsForm from 'ee/ai/settings/components/duo_workflow_settings_form.vue';

describe('DuoWorkflowSettingsForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(DuoWorkflowSettingsForm, {
      propsData: {
        isMcpEnabled: false,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  it('renders the section title correctly', () => {
    expect(wrapper.find('h5').text()).toBe('Model Context Protocol');
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().exists()).toBe(true);
    expect(findFormCheckbox().text()).toContain('Turn on Model Context Protocol (MCP) support');
  });

  it('renders the help text correctly', () => {
    expect(findFormCheckbox().text()).toContain(
      'Turn on MCP support for GitLab Duo Agentic Chat and GitLab Duo Workflow',
    );
  });

  it.each([[false], [true]])(
    'sets checkbox with the isMcpEnabled prop %p',
    async (isMcpEnabled) => {
      wrapper = createComponent({ isMcpEnabled });

      await nextTick();

      if (isMcpEnabled) {
        expect(findFormCheckbox().attributes('checked')).toBe(String(isMcpEnabled));
      } else {
        expect(findFormCheckbox().attributes('checked')).toBeUndefined();
      }
    },
  );

  it('emits change event with correct value when checkbox is clicked', async () => {
    findFormCheckbox().vm.$emit('change', true);
    await nextTick();

    expect(wrapper.emitted('change')[0]).toEqual([true]);
  });

  it('renders checkbox with correct data-testid attribute', () => {
    expect(findFormCheckbox().attributes('data-testid')).toBe(
      'enable-duo-workflow-mcp-enabled-checkbox',
    );
  });

  it('renders checkbox with correct name attribute', () => {
    expect(findFormCheckbox().attributes('name')).toBe(
      'namespace[ai_settings_attributes][duo_workflow_mcp_enabled]',
    );
  });
});
