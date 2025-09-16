import {
  GlButton,
  GlFormInput,
  GlFormTextarea,
  GlForm,
  GlExperimentBadge,
  GlFormFields,
  GlAlert,
  GlEmptyState,
  GlModal,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EditAgent from 'ee/ml/ai_agents/views/edit_agent.vue';
import getLatestAiAgentVersionQuery from 'ee/ml/ai_agents/graphql/queries/get_latest_ai_agent_version.query.graphql';
import updateAiAgentMutation from 'ee/ml/ai_agents/graphql/mutations/update_ai_agent.mutation.graphql';
import destroyAiAgentMutation from 'ee/ml/ai_agents//graphql/mutations/destroy_ai_agent.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import {
  updateAiAgentsResponses,
  getLatestAiAgentResponse,
  getLatestAiAgentErrorResponse,
  getLatestAiAgentNotFoundResponse,
  destroyAiAgentsResponses,
} from '../graphql/mocks';

Vue.use(VueApollo);

const push = jest.fn();
const $router = {
  push,
};

describe('ee/ml/ai_agents/views/edit_agent', () => {
  let wrapper;
  let apolloMocks;
  const agentId = 1;

  const createComponent = () => {
    const apolloProvider = createMockApollo(apolloMocks);

    wrapper = mountExtended(EditAgent, {
      apolloProvider,
      provide: { projectPath: 'path/to/project' },
      mocks: {
        $router,
        $route: {
          params: {
            agentId,
          },
        },
      },
    });
  };

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findButton = () => wrapper.findComponent(GlButton);
  const findDeleteModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const submitForm = async () => {
    findForm().vm.$emit('submit', { preventDefault: () => {} });
    await waitForPromises();
  };

  describe('when the agent data has successfully loaded', () => {
    beforeEach(async () => {
      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
      ];
      createComponent();
      await waitForPromises();
    });

    it('renders the page title', () => {
      expect(findTitleArea().text()).toContain('Agent Settings');
    });

    it('displays the experiment badge', () => {
      expect(findBadge().exists()).toBe(true);
    });

    it('renders the button', () => {
      expect(findButton().text()).toBe('Update agent');
    });

    it('renders the form and expected inputs', () => {
      expect(findForm().exists()).toBe(true);
      expect(findInput().exists()).toBe(true);
      expect(findTextarea().exists()).toBe(true);
      expect(findFormFields().props('values').name).toEqual('agent-1');
      expect(findFormFields().props('values').prompt).toEqual('example prompt');
    });
  });

  describe('when the agent data fails to load', () => {
    beforeEach(async () => {
      apolloMocks = [
        [
          getLatestAiAgentVersionQuery,
          jest.fn().mockResolvedValueOnce(getLatestAiAgentNotFoundResponse),
        ],
      ];
      createComponent();
      await waitForPromises();
    });

    it('displays an error', () => {
      expect(findEmptyState().text()).toBe('The requested agent was not found.');
    });
  });

  describe('when an exceptions happens loading data', () => {
    beforeEach(async () => {
      apolloMocks = [
        [
          getLatestAiAgentVersionQuery,
          jest.fn().mockResolvedValueOnce(getLatestAiAgentErrorResponse),
        ],
      ];
      createComponent();
      await waitForPromises();
    });

    it('displays an error', () => {
      expect(findErrorAlert().text()).toBe(
        'GraphQL error: An error has occurred when loading the agent.',
      );
    });
  });

  describe('when successfully updating the agent data', () => {
    let resolver;

    beforeEach(async () => {
      resolver = jest.fn().mockResolvedValueOnce(updateAiAgentsResponses.success);
      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
        [updateAiAgentMutation, resolver],
      ];

      createComponent();
      await waitForPromises();
    });

    it('submits the update with correct parameters', async () => {
      await findInput().vm.$emit('input', 'agent_1');
      await findTextarea().vm.$emit('input', 'Do something');

      await submitForm();

      expect(resolver).toHaveBeenLastCalledWith(
        expect.objectContaining({
          agentId: 'gid://gitlab/Ai::Agent/1',
          projectPath: 'path/to/project',
          name: 'agent_1',
          prompt: 'Do something',
        }),
      );
    });

    it('navigates to the new page when result is successful', async () => {
      await findInput().vm.$emit('input', 'agent_1');
      await findTextarea().vm.$emit('input', 'Do something');

      await submitForm();

      expect($router.push).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'show',
          params: { agentId: 2 },
        }),
      );
    });
  });

  describe('when updating the agent data fails', () => {
    it('shows errors when result is a top level error', async () => {
      const error = new Error('Failure!');
      const resolver = jest.fn().mockRejectedValue({ error });
      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
        [updateAiAgentMutation, resolver],
      ];

      createComponent();
      await waitForPromises();

      await submitForm();

      expect(findErrorAlert().text()).toBe('An error has occurred when saving the agent.');
      expect($router.push).not.toHaveBeenCalled();
    });

    it('shows errors when result is a validation error', async () => {
      const resolver = jest.fn().mockResolvedValueOnce(updateAiAgentsResponses.validationFailure);

      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
        [updateAiAgentMutation, resolver],
      ];

      createComponent();
      await waitForPromises();
      await submitForm();

      expect(findErrorAlert().text()).toBe('Name is invalid');
      expect($router.push).not.toHaveBeenCalled();
    });
  });

  describe('when successfully destroying the agent data', () => {
    let resolver;

    beforeEach(async () => {
      resolver = jest.fn().mockResolvedValueOnce(destroyAiAgentsResponses.success);
      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
        [destroyAiAgentMutation, resolver],
      ];

      createComponent();
      await waitForPromises();
    });

    it('submits the destroy request', () => {
      findDeleteModal().vm.$emit('primary');

      expect(resolver).toHaveBeenLastCalledWith(
        expect.objectContaining({
          agentId: 'gid://gitlab/Ai::Agent/1',
          projectPath: 'path/to/project',
        }),
      );
    });

    it('navigates to the new page when result is successful', async () => {
      findDeleteModal().vm.$emit('primary');
      await waitForPromises();

      expect($router.push).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'list',
        }),
      );
    });
  });

  describe('when destroying the agent fails', () => {
    let resolver;

    it('shows errors when result is a top level error', async () => {
      resolver = jest.fn().mockResolvedValueOnce(destroyAiAgentsResponses.error);
      apolloMocks = [
        [getLatestAiAgentVersionQuery, jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse)],
        [destroyAiAgentMutation, resolver],
      ];

      createComponent();
      await waitForPromises();

      findDeleteModal().vm.$emit('primary');
      await waitForPromises();

      expect(findErrorAlert().text()).toBe('AI Agent not found');
      expect($router.push).not.toHaveBeenCalled();
    });
  });
});
