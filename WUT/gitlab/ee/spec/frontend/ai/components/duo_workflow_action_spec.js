import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import DuoWorkflowAction from 'ee/ai/components/duo_workflow_action.vue';

jest.mock('~/alert');

describe('DuoWorkflowAction component', () => {
  let wrapper;

  const projectId = 123;
  const duoWorkflowInvokePath = `/api/v4/projects/${projectId}/duo_workflows`;
  const pipelineId = 987;
  const pipelinePath = `/project/${projectId}/pipelines/${pipelineId}`;
  const currentRef = 'feature-branch';

  const mockPipelineData = {
    pipeline: {
      id: pipelineId,
      path: pipelinePath,
    },
  };

  const defaultProps = {
    projectId,
    title: 'Convert to GitLab CI/CD',
    hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
    goal: 'Jenkinsfile',
    workflowDefinition: 'convert_to_gitlab_ci',
    agentPrivileges: [1, 2, 5],
    duoWorkflowInvokePath,
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMount(DuoWorkflowAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    jest.spyOn(axios, 'post');
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders button with correct props', () => {
      expect(findButton().props('category')).toBe('primary');
      expect(findButton().props('icon')).toBe('tanuki-ai');
      expect(findButton().props('size')).toBe('small');
      expect(findButton().attributes('title')).toBe(defaultProps.hoverMessage);
      expect(findButton().text()).toBe(defaultProps.title);
    });
  });

  describe('startWorkflow', () => {
    const expectedRequestData = {
      project_id: projectId,
      start_workflow: true,
      environment: 'web',
      goal: defaultProps.goal,
      workflow_definition: defaultProps.workflowDefinition,
      agent_privileges: defaultProps.agentPrivileges,
    };

    beforeEach(() => {
      createComponent();
    });

    describe('when the goal fails to match the promptValidatorRegex', () => {
      const invalidGoal = 'InvalidPath';

      beforeEach(() => {
        createComponent({ goal: invalidGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ });
        findButton().vm.$emit('click');
      });

      it('emits prompt-validation-error', () => {
        expect(wrapper.emitted('prompt-validation-error')).toEqual([[invalidGoal]]);
        expect(axios.post).not.toHaveBeenCalled();
      });
    });

    describe('when the goal matches the promptVaidatorRegex', () => {
      const validGoal = 'Jenkinsfile';

      beforeEach(() => {
        axios.post.mockResolvedValue({ data: mockPipelineData });
        createComponent({ goal: validGoal, promptValidatorRegex: /.*[Jj]enkinsfile.*/ });
        findButton().vm.$emit('click');
      });

      it('does not emit prompt-validation-error when goal matches regex', () => {
        expect(wrapper.emitted('prompt-validation-error')).toBeUndefined();
        expect(axios.post).toHaveBeenCalled();
      });
    });

    it('makes API call with correct data when button is clicked', async () => {
      axios.post.mockResolvedValue({ data: mockPipelineData });

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(axios.post).toHaveBeenCalledWith(duoWorkflowInvokePath, expectedRequestData);
    });

    it('includes source_branch when currentRef is provided', async () => {
      createComponent({}, { currentRef });
      axios.post.mockResolvedValue({ data: mockPipelineData });

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(axios.post).toHaveBeenCalledWith(duoWorkflowInvokePath, {
        ...expectedRequestData,
        source_branch: currentRef,
      });
    });

    describe('when request succeeds', () => {
      beforeEach(() => {
        axios.post.mockResolvedValue({ data: mockPipelineData });
        findButton().vm.$emit('click');
      });

      it('shows success alert with pipeline link', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            variant: 'success',
            data: mockPipelineData,
            renderMessageHTML: true,
            message: 'Workflow started successfully',
          }),
        );
      });

      it('emits agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toEqual([[mockPipelineData]]);
      });
    });

    describe('when request fails', () => {
      const error = new Error('API error');

      beforeEach(() => {
        axios.post.mockRejectedValue(error);
        findButton().vm.$emit('click');
      });

      it('shows error alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error occurred when starting the workflow',
          captureError: true,
          error,
        });
      });

      it('does not emits agent-flow-started event', () => {
        expect(wrapper.emitted('agent-flow-started')).toBeUndefined();
      });
    });
  });
});
