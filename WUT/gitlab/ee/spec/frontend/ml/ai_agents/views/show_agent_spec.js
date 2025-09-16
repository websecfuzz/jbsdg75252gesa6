import { GlExperimentBadge, GlEmptyState } from '@gitlab/ui';
import { DuoChat } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getMarkdown } from '~/rest_api';
import ShowAgent from 'ee/ml/ai_agents/views/show_agent.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import getLatestAiAgentVersionQuery from 'ee/ml/ai_agents/graphql/queries/get_latest_ai_agent_version.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import {
  MOCK_USER_MESSAGE,
  MOCK_USER_ID,
  MOCK_TANUKI_SUCCESS_RES,
  MOCK_TANUKI_BOT_MUTATATION_RES,
} from 'ee_jest/ai/tanuki_bot/mock_data';
import {
  getLatestAiAgentResponse,
  getLatestAiAgentNotFoundResponse,
} from 'ee_jest/ml/ai_agents/graphql/mocks';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';

Vue.use(VueApollo);

jest.mock('~/rest_api');

const skipReason = new SkipReason({
  name: 'ee/ml/ai_agents/views/show_agent',
  reason: 'CPU pegged at 100%',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/458410',
});

describeSkipVue3(skipReason, () => {
  let wrapper;
  let latestAiAgentResponseMock;

  const subscriptionHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_SUCCESS_RES);
  const chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
  const agentId = 2;

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findSettingsButton = () => wrapper.findByTestId('settings-button');
  const findDuoChat = () => wrapper.findComponent(DuoChat);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const createWrapper = () => {
    const apolloProvider = createMockApollo([
      [aiResponseSubscription, subscriptionHandlerMock],
      [chatMutation, chatMutationHandlerMock],
      [getLatestAiAgentVersionQuery, latestAiAgentResponseMock],
    ]);

    wrapper = shallowMountExtended(ShowAgent, {
      apolloProvider,
      provide: { projectPath: 'path/to/project', userId: MOCK_USER_ID },
      stubs: {
        RouterLink,
      },
      mocks: {
        $route: {
          params: {
            agentId,
          },
        },
      },
    });
  };

  beforeEach(() => {
    latestAiAgentResponseMock = jest.fn().mockResolvedValueOnce(getLatestAiAgentResponse);
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
  });

  describe('rendering', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('shows the title', () => {
      expect(findTitleArea().text()).toContain('agent-1');
    });

    it('shows the settings button', () => {
      expect(findSettingsButton().exists()).toBe(true);
    });

    it('displays the experiment badge', () => {
      expect(findBadge().exists()).toBe(true);
    });

    it('renders the DuoChat component', () => {
      expect(findDuoChat().exists()).toBe(true);
    });
  });

  describe('when the requested agent is not found', () => {
    beforeEach(async () => {
      latestAiAgentResponseMock = jest.fn().mockResolvedValueOnce(getLatestAiAgentNotFoundResponse);
      createWrapper();
      await waitForPromises();
    });

    it('shows the error message', () => {
      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('@send-chat-prompt', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('does set loading to `true` for a user message', async () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();
      expect(findDuoChat().props('isLoading')).toBe(true);
    });

    it('calls correct GraphQL mutation', async () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();
      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        resourceId: MOCK_USER_ID,
        agentVersionId: 'gid://gitlab/Ai::AgentVersion/1',
        question: MOCK_USER_MESSAGE.content,
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Fancy foo';

    describe('when subscription fails', () => {
      beforeEach(async () => {
        subscriptionHandlerMock.mockRejectedValue(new Error(errorText));
        createWrapper();
        await waitForPromises();
      });

      it('throws error and displays error message', () => {
        expect(findDuoChat().props('error')).toBe(`Error: ${errorText}`);
      });
    });

    describe('when mutation fails', () => {
      beforeEach(async () => {
        chatMutationHandlerMock.mockRejectedValue(new Error(errorText));
        createWrapper();
        await waitForPromises();
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
      });

      it('throws error and displays error message', () => {
        expect(findDuoChat().props('error')).toBe(`Error: ${errorText}`);
      });
    });
  });
});
