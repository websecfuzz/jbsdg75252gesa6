import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox, GlFormTextarea, GlFormGroup } from '@gitlab/ui';

import waitForPromises from 'helpers/wait_for_promises';
import { AGENTFLOW_TYPE_JENKINS_TO_CI } from 'ee/ai/duo_agents_platform/constants';
import RunAgentFlowForm from 'ee/ai/duo_agents_platform/components/common/run_agent_flow_form.vue';
import DuoAgentFlowAction from 'ee/ai/components/duo_workflow_action.vue';

describe('RunAgentFlowForm', () => {
  let wrapper;

  const defaultProps = {
    defaultAgentFlowType: AGENTFLOW_TYPE_JENKINS_TO_CI,
    duoAgentsInvokePath: '/api/v4/projects/123/duo_workflow/invoke',
    projectId: 123,
    flows: [
      {
        value: AGENTFLOW_TYPE_JENKINS_TO_CI,
        text: 'Convert Jenkins to CI',
        agentPrivileges: [1, 2, 5],
        promptValidatorRegex: /.*[Jj]enkinsfile.*/,
        helperText: 'Enter the path to your Jenkinsfile.',
        validationErrorMessage: 'Path must be a Jenkinsfile with the exact matching case.',
      },
    ],
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(RunAgentFlowForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findAgentFlowSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPromptTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findFormGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findDuoAgentFlowAction = () => wrapper.findComponent(DuoAgentFlowAction);

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the agentFlow selector form group', () => {
      const formGroups = findFormGroups();
      expect(formGroups.at(0).attributes('label')).toBe('Select a flow');
    });

    it('renders the prompt form group', () => {
      const formGroups = findFormGroups();
      expect(formGroups.at(1).attributes('label')).toBe('Prompt');
    });

    it('renders the agentFlow selector with correct props', () => {
      const agentflowSelector = findAgentFlowSelector();

      expect(agentflowSelector.exists()).toBe(true);
      expect(agentflowSelector.props('items')[0]).toEqual(
        expect.objectContaining({
          value: 'convert_to_gitlab_ci',
          text: 'Convert Jenkins to CI',
        }),
      );
      expect(agentflowSelector.props('selected')).toBe('convert_to_gitlab_ci');
      expect(agentflowSelector.props('toggleText')).toBe('Convert Jenkins to CI');
    });

    it('renders the prompt textarea with correct props', () => {
      const textarea = findPromptTextarea();

      expect(textarea.exists()).toBe(true);
      expect(textarea.attributes('placeholder')).toBe('Enter the path to your Jenkinsfile.');
      expect(textarea.props('rows')).toBe('6');
      expect(textarea.props('value')).toBe('');
    });

    it('renders the DuoAgentFlowAction component with correct props', () => {
      const workflowAction = findDuoAgentFlowAction();

      expect(workflowAction.exists()).toBe(true);
      expect(workflowAction.props()).toEqual({
        projectId: 123,
        title: 'Start agent session',
        hoverMessage: '',
        goal: '',
        size: 'small',
        workflowDefinition: 'convert_to_gitlab_ci',
        duoWorkflowInvokePath: '/api/v4/projects/123/duo_workflow/invoke',
        agentPrivileges: [1, 2, 5],
        promptValidatorRegex: /.*[Jj]enkinsfile.*/,
      });
    });
  });

  describe('when agentFlow is selected', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('updates the selected agentFlow when dropdown selection changes', async () => {
      const agentflowSelector = findAgentFlowSelector();

      await agentflowSelector.vm.$emit('select', 'convert_to_gitlab_ci');

      expect(findDuoAgentFlowAction().props('workflowDefinition')).toBe('convert_to_gitlab_ci');
    });
  });

  describe('when the agentFlow-stated is emitted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits the agent-flow-started event', async () => {
      const workflowAction = findDuoAgentFlowAction();

      workflowAction.vm.$emit('agent-flow-started', { id: 123 });
      await waitForPromises();

      expect(wrapper.emitted('agent-flow-started')[0]).toEqual([{ id: 123 }]);
    });
  });

  describe('Prompt', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('when prompt is empty', () => {
      it('disables the start agentFlow button', () => {
        // Vue3 is disabled, Vue 2 is true
        // eslint-disable-next-line jest/no-restricted-matchers
        expect(findDuoAgentFlowAction().attributes('disabled')).toBeTruthy();
      });
    });

    describe('when prompt has content', () => {
      beforeEach(async () => {
        const textarea = findPromptTextarea();
        await textarea.vm.$emit('input', 'Convert my Jenkins pipeline to GitLab CI');
      });

      it('enables the start agentFlow button', () => {
        expect(findDuoAgentFlowAction().attributes('disabled')).toBeUndefined();
      });

      it('passes the prompt as goal to DuoAgentFlowAction', () => {
        expect(findDuoAgentFlowAction().props('goal')).toBe(
          'Convert my Jenkins pipeline to GitLab CI',
        );
      });
    });

    describe('when prompt has only whitespace', () => {
      beforeEach(async () => {
        const textarea = findPromptTextarea();
        await textarea.vm.$emit('input', '   \n\t   ');
      });

      it('keeps the start agentFlow button disabled', () => {
        // Vue3 is disabled, Vue 2 is true
        // eslint-disable-next-line jest/no-restricted-matchers
        expect(findDuoAgentFlowAction().attributes('disabled')).toBeTruthy();
      });
    });
  });
});
