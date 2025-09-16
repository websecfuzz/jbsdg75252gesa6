import {
  GlButton,
  GlFormInput,
  GlFormTextarea,
  GlForm,
  GlExperimentBadge,
  GlAlert,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import CreateAgent from 'ee/ml/ai_agents/views/create_agent.vue';
import createAiAgentMutation from 'ee/ml/ai_agents/graphql/mutations/create_ai_agent.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import { createAiAgentsResponses } from '../graphql/mocks';

describe('ee/ml/ai_agents/views/create_agent', () => {
  let wrapper;
  let apolloProvider;

  const push = jest.fn();
  const $router = {
    push,
  };

  Vue.use(VueApollo);

  beforeEach(() => {
    jest.spyOn(Sentry, 'captureException').mockImplementation();
  });

  const mountComponent = (
    resolver = jest.fn().mockResolvedValue(createAiAgentsResponses.success),
  ) => {
    const requestHandlers = [[createAiAgentMutation, resolver]];
    apolloProvider = createMockApollo(requestHandlers);

    wrapper = mountExtended(CreateAgent, {
      apolloProvider,
      provide: { projectPath: 'project/path' },
      mocks: {
        $router,
      },
    });
  };

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findButton = () => wrapper.findComponent(GlButton);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findForm = () => wrapper.findComponent(GlForm);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  const submitForm = async () => {
    findForm().vm.$emit('submit', { preventDefault: () => {} });
    await waitForPromises();
  };

  it('shows the title', () => {
    mountComponent();

    expect(findTitleArea().text()).toContain('New agent');
  });

  it('displays the experiment badge', () => {
    mountComponent();

    expect(findBadge().exists()).toBe(true);
  });

  it('renders the button', () => {
    mountComponent();

    expect(findButton().text()).toBe('Create agent');
  });

  it('submits the query with correct parameters', async () => {
    const resolver = jest.fn().mockResolvedValue(createAiAgentMutation.success);
    mountComponent(resolver);

    await findInput().vm.$emit('input', 'agent_1');
    await findTextarea().vm.$emit('input', 'Do something');

    await submitForm();

    expect(resolver).toHaveBeenLastCalledWith(
      expect.objectContaining({
        projectPath: 'project/path',
        name: 'agent_1',
        prompt: 'Do something',
      }),
    );
  });

  it('navigates to the new page when result is successful', async () => {
    mountComponent();

    await submitForm();

    expect($router.push).toHaveBeenCalledWith({
      name: 'show',
      params: { agentId: 2 },
    });
  });

  it('shows errors when result is a top level error', async () => {
    const error = new Error('Failure!');
    mountComponent(jest.fn().mockRejectedValue({ error }));

    await submitForm();

    expect(findErrorAlert().text()).toBe('An error has occurred when saving the agent.');
    expect(push).not.toHaveBeenCalled();
  });

  it('shows errors when result is a validation error', async () => {
    mountComponent(jest.fn().mockResolvedValue(createAiAgentsResponses.validationFailure));

    await submitForm();

    expect(findErrorAlert().text()).toBe("Name is invalid, Name can't be blank");
    expect(push).not.toHaveBeenCalled();
  });
});
