import { DuoChat } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
import { v4 as uuidv4 } from 'uuid';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { sendDuoChatCommand, setAgenticMode } from 'ee/ai/utils';
import TanukiBotChatApp from 'ee/ai/tanuki_bot/components/app.vue';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import TanukiBotSubscriptions from 'ee/ai/tanuki_bot/components/tanuki_bot_subscriptions.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
} from 'ee/ai/constants';
import { TANUKI_BOT_TRACKING_EVENT_NAME, WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import chatWithNamespaceMutation from 'ee/ai/graphql/chat_with_namespace.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import deleteConversationThreadMutation from 'ee/ai/graphql/delete_conversation_thread.mutation.graphql';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import getAiMessagesWithThread from 'ee/ai/graphql/get_ai_messages_with_thread.query.graphql';
import getAiConversationThreads from 'ee/ai/graphql/get_ai_conversation_threads.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getMarkdown } from '~/rest_api';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';
import getAiSlashCommands from 'ee/ai/graphql/get_ai_slash_commands.query.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { getCookie } from '~/lib/utils/common_utils';

import {
  MOCK_USER_MESSAGE,
  MOCK_USER_ID,
  MOCK_RESOURCE_ID,
  MOCK_CHUNK_MESSAGE,
  MOCK_TANUKI_BOT_MUTATATION_RES,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHAT_CACHED_MESSAGES_RES,
  MOCK_SLASH_COMMANDS,
  MOCK_TANUKI_MESSAGE,
  MOCK_THREADS,
  MOCK_THREADS_RESPONSE,
  MOCK_CONTEXT_PRESETS_RESPONSE,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/rest_api');
jest.mock('uuid');

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
  setCookie: jest.fn(),
}));

jest.mock('ee/ai/utils', () => {
  const actualUtils = jest.requireActual('ee/ai/utils');

  return {
    __esModule: true,
    ...actualUtils,
    setAgenticMode: jest.fn(),
  };
});

const skipReason = new SkipReason({
  name: 'GitLab Duo Chat',
  reason: 'Test times out (CPU pegged at 100%)',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/458409',
});

describeSkipVue3(skipReason, () => {
  let wrapper;

  const UUIDMOCK = '123';

  const actionSpies = {
    addDuoChatMessage: jest.fn(),
    setMessages: jest.fn(),
    setLoading: jest.fn(),
  };

  const chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
  const chatWithNamespaceMutationHandlerMock = jest
    .fn()
    .mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
  const duoUserFeedbackMutationHandlerMock = jest.fn().mockResolvedValue({});
  const deleteConversationThreadMutationHandlerMock = jest.fn().mockResolvedValue({});
  const queryHandlerMock = jest.fn().mockResolvedValue(MOCK_CHAT_CACHED_MESSAGES_RES);
  const threadQueryHandlerMock = jest.fn().mockResolvedValue({});
  const conversationThreadsQueryHandlerMock = jest.fn().mockResolvedValue({});
  const slashCommandsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_SLASH_COMMANDS);
  const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const feedbackData = {
    feedbackChoices: ['useful', 'not_relevant'],
    didWhat: 'provided clarity',
    improveWhat: 'more examples',
    message: {
      requestId: '1234567890',
      id: 'abcdefgh',
      role: 'user',
      content: 'test',
      extras: {
        exampleExtraContent: 1,
      },
    },
  };

  const findCallout = () => wrapper.findComponent(DuoChatCallout);
  const findSubscriptions = () => wrapper.findComponent(TanukiBotSubscriptions);

  const createComponent = ({
    initialState = {},
    propsData = { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID },
    data = {},
    glFeatures = { duoChatDynamicDimension: false },
  } = {}) => {
    const store = new Vuex.Store({
      actions: actionSpies,
      state: {
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [chatMutation, chatMutationHandlerMock],
      [chatWithNamespaceMutation, chatWithNamespaceMutationHandlerMock],
      [duoUserFeedbackMutation, duoUserFeedbackMutationHandlerMock],
      [deleteConversationThreadMutation, deleteConversationThreadMutationHandlerMock],
      [getAiMessages, queryHandlerMock],
      [getAiMessagesWithThread, threadQueryHandlerMock],
      [getAiConversationThreads, conversationThreadsQueryHandlerMock],
      [getAiSlashCommands, slashCommandsQueryHandlerMock],
      [getAiChatContextPresets, contextPresetsQueryHandlerMock],
    ]);

    if (duoChatGlobalState.isShown !== false) {
      duoChatGlobalState.isShown = true;
    }

    wrapper = shallowMountExtended(TanukiBotChatApp, {
      store,
      apolloProvider,
      propsData,
      data() {
        return data;
      },
      provide: {
        glFeatures,
      },
    });
  };

  const findDuoChat = () => wrapper.findComponent(DuoChat);

  beforeEach(() => {
    uuidv4.mockImplementation(() => UUIDMOCK);
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.commands = [];
    duoChatGlobalState.isShown = false;
  });

  it('generates unique `clientSubscriptionId` using v4', () => {
    createComponent();
    expect(uuidv4).toHaveBeenCalled();
    expect(wrapper.vm.clientSubscriptionId).toBe('123');
  });

  describe('fetching the cached messages', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
      });

      it('fetches the cached messages on mount and updates the messages with the returned result', async () => {
        createComponent();
        expect(queryHandlerMock).toHaveBeenCalled();
        await waitForPromises();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_CHAT_CACHED_MESSAGES_RES.data.aiMessages.nodes,
        );
      });

      it('updates the messages even if the returned result has no messages', async () => {
        queryHandlerMock.mockResolvedValue({
          data: {
            aiMessages: {
              nodes: [],
            },
          },
        });
        createComponent();
        await waitForPromises();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = false;
      });

      it('does not fetch cached messages', () => {
        createComponent();
        expect(queryHandlerMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isShown = true;
      });

      it('renders the DuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('sets correct `badge-type` and `badge-help-page-url` props on the chat component', () => {
        expect(findDuoChat().props('badgeType')).toBe(null);
      });

      it('calls the slash commands GraphQL query when component loads', () => {
        expect(slashCommandsQueryHandlerMock).toHaveBeenCalledWith({
          url: 'http://test.host/',
        });
      });

      it('calls the context presets GraphQL query when component loads', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
          url: 'http://test.host/',
          questionCount: 4,
        });
      });

      it('passes the correct slash commands to the DuoChat component', async () => {
        await waitForPromises();

        const duoChat = findDuoChat();

        expect(duoChat.props('slashCommands')).toEqual([
          {
            description: 'New chat conversation.',
            name: '/new',
            shouldSubmit: false,
          },
          {
            description: 'Learn what Duo Chat can do.',
            name: '/help',
            shouldSubmit: true,
          },
        ]);
      });

      it('renders the duo-chat-callout component', () => {
        expect(findCallout().exists()).toBe(true);
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isShown = false;
      });

      it('does not call the slash commands GraphQL query', () => {
        expect(slashCommandsQueryHandlerMock).not.toHaveBeenCalled();
      });

      it('does not call the context presets GraphQL query', () => {
        expect(contextPresetsQueryHandlerMock).not.toHaveBeenCalled();
      });

      it('does not render the DuoChat component', () => {
        expect(findDuoChat().exists()).toBe(false);
      });
    });
  });

  describe('contextPresets', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = true;
      createComponent();
    });

    it('passes context presets to DuoChat component as predefinedPrompts', async () => {
      await waitForPromises();

      expect(findDuoChat().props('predefinedPrompts')).toEqual(
        MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
      );
    });
  });

  describe('when new commands are added to the global state', () => {
    let originalRequestIdleCallback;

    beforeEach(async () => {
      originalRequestIdleCallback = window.requestIdleCallback;
      window.requestIdleCallback = (callback) => callback();

      createComponent();
      duoChatGlobalState.isShown = true;
      await waitForPromises();
      performance.mark = jest.fn();
    });

    afterEach(() => {
      duoChatGlobalState.commands = [];
      window.requestIdleCallback = originalRequestIdleCallback;
    });

    it('resets chat', async () => {
      const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
      await nextTick();
      expect(onNewChatSpy).toHaveBeenCalled();
    });

    it('calls the chat mutation', async () => {
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
      await waitForPromises();
      expect(chatMutationHandlerMock).toHaveBeenCalledTimes(1);
    });

    it('uses the command resourceId', async () => {
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: 'command::1' });
      await waitForPromises();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: '/troubleshoot',
        resourceId: 'command::1',
        projectId: null,
        conversationType: 'DUO_CHAT',
        threadId: undefined,
      });
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isShown).toBe(false);
        expect(findDuoChat().exists()).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      beforeEach(() => {
        performance.mark = jest.fn();
      });

      it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'resets chat state when "%s" command is sent',
        async (command) => {
          createComponent();
          findDuoChat().vm.$emit('send-chat-prompt', command);
          await nextTick();

          const duoChat = findDuoChat();
          expect(duoChat.props('activeThreadId')).toBe('');
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(duoChat.props('multiThreadedView')).toBe('chat');
          expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
          expect(duoChat.props('canceledRequestIds')).toEqual([]);
          expect(chatMutationHandlerMock).not.toHaveBeenCalled();
        },
      );

      it('does set loading to `true` unless a new chat is requested', () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(actionSpies.setLoading).toHaveBeenCalled();
      });

      it('starts the performance measurement when sending a prompt', () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(performance.mark).toHaveBeenCalledWith('prompt-sent');
      });

      it('calls the chat mutation with projectId when available', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, resourceId: null, projectId: 'project-123' },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_USER_ID,
          projectId: 'project-123',
          conversationType: 'DUO_CHAT',
          threadId: undefined,
        });
      });

      it('calls the chat mutation without projectId if it is not provided', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID, projectId: null },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
          conversationType: 'DUO_CHAT',
          threadId: undefined,
        });
      });

      it('sends the chat mutation with correct headers', async () => {
        createComponent();

        // Spy on the Apollo mutate method to capture the full mutation options
        const mutateSpy = jest.spyOn(wrapper.vm.$apollo, 'mutate');

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(mutateSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            mutation: chatMutation,
            variables: expect.any(Object),
            context: {
              headers: {
                'X-GitLab-Interface': 'duo_chat',
                'X-GitLab-Client-Type': 'web_browser',
              },
            },
          }),
        );
      });

      describe.each`
        resourceId          | expectedResourceId
        ${MOCK_RESOURCE_ID} | ${MOCK_RESOURCE_ID}
        ${null}             | ${MOCK_USER_ID}
      `(`with resourceId = $resourceId`, ({ resourceId, expectedResourceId }) => {
        it('calls correct GraphQL mutation with fallback to userId when input is submitted', async () => {
          createComponent({
            propsData: { userId: MOCK_USER_ID, resourceId },
          });
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await nextTick();

          expect(chatMutationHandlerMock).toHaveBeenCalledWith({
            resourceId: expectedResourceId,
            question: MOCK_USER_MESSAGE.content,
            clientSubscriptionId: '123',
            projectId: null,
            conversationType: 'DUO_CHAT',
            threadId: undefined,
          });
        });
      });

      describe('tracking on mutation', () => {
        const expectedCategory = undefined;
        const expectedAction = 'submit_gitlab_duo_question';
        const defaultTrackingOption = {
          property: MOCK_TANUKI_BOT_MUTATATION_RES.data.aiAction.requestId,
        };

        beforeEach(async () => {
          createComponent();
          await waitForPromises();
        });

        it('tracks the submission for prompts by default', async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await waitForPromises();
          expect(trackEventSpy).toHaveBeenCalledWith(
            expectedAction,
            defaultTrackingOption,
            expectedCategory,
          );
        });

        it('tracks context preset prompts with the correct event label', async () => {
          const question = MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions[0];

          const expectedEventLabel = 'what_are_the_main_points_from_this_mr_discussion';
          const expectedTrackingOption = {
            ...defaultTrackingOption,
            label: expectedEventLabel,
          };

          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findDuoChat().vm.$emit('send-chat-prompt', question);

          await waitForPromises();
          expect(trackEventSpy).toHaveBeenCalledWith(
            expectedAction,
            expectedTrackingOption,
            expectedCategory,
          );
        });

        it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
          'does not track if the sent message is "%s"',
          async (msg) => {
            createComponent();
            const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
            findDuoChat().vm.$emit('send-chat-prompt', msg);

            await waitForPromises();
            expect(trackEventSpy).not.toHaveBeenCalled();
          },
        );
      });
    });

    describe('@response-received', () => {
      beforeEach(() => {
        performance.mark = jest.fn();
        performance.measure = jest.fn();
        performance.getEntriesByName = jest.fn(() => [{ duration: 123 }]);
        performance.clearMarks = jest.fn();
        performance.clearMeasures = jest.fn();
      });

      it('tracks time to response on first response-received', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findSubscriptions().vm.$emit('response-received', 'request-id-123');

        expect(performance.mark).toHaveBeenCalledWith('response-received');

        expect(trackEventSpy).toHaveBeenCalledWith(
          'ai_response_time',
          {
            property: 'request-id-123',
            value: 123,
          },
          undefined,
        );
      });

      it('does not track time to response after first chunk was tracked', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findSubscriptions().vm.$emit('response-received', 'request-id-123');
        findSubscriptions().vm.$emit('response-received', 'request-id-123');

        expect(performance.mark).toHaveBeenCalledTimes(1);
        expect(trackEventSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('@track-feedback', () => {
      it('calls the feedback GraphQL mutation when message is passed', async () => {
        createComponent();
        findDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(duoUserFeedbackMutationHandlerMock).toHaveBeenCalledWith({
          input: {
            aiMessageId: feedbackData.message.id,
            trackingEvent: {
              category: TANUKI_BOT_TRACKING_EVENT_NAME,
              action: 'duo_chat',
              label: 'response_feedback',
              property: 'useful,not_relevant',
              extra: {
                improveWhat: 'more examples',
                didWhat: 'provided clarity',
                prompt_location: 'after_content',
              },
            },
          },
        });
      });

      it('updates Vuex store correctly when message is passed', async () => {
        createComponent();
        findDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.any(Object),
          expect.objectContaining({
            requestId: feedbackData.message.requestId,
            role: feedbackData.message.role,
            content: feedbackData.message.content,
            extras: { ...feedbackData.message.extras, hasFeedback: true },
          }),
        );
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Fancy foo';

    it('does call addDuoChatMessage', async () => {
      queryHandlerMock.mockImplementationOnce(() => Promise.reject(new Error(errorText)));
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });

    describe('when mutation fails', () => {
      it('throws an error, but still calls addDuoChatMessage', async () => {
        chatMutationHandlerMock.mockRejectedValue(new Error(errorText));
        duoChatGlobalState.isShown = true;
        createComponent();
        await waitForPromises();
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
          }),
        );
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [`Error: ${errorText}`],
          }),
        );
      });
    });

    it('handles errors from the context presets query', async () => {
      contextPresetsQueryHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      expect(findDuoChat().exists()).toBe(true);
      expect(findDuoChat().props('predefinedPrompts')).toEqual([]);
    });
  });

  describe('Subscription Component', () => {
    afterEach(() => {
      duoChatGlobalState.isShown = false;
      jest.clearAllMocks();
    });

    it('renders AiResponseSubscription component with correct props when isShown is true', async () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      expect(findSubscriptions().exists()).toBe(true);
      expect(findSubscriptions().props('userId')).toBe(MOCK_USER_ID);
      expect(findSubscriptions().props('clientSubscriptionId')).toBe(UUIDMOCK);
      expect(findSubscriptions().props('cancelledRequestIds')).toHaveLength(0);
    });

    it('does not render AiResponseSubscription component when isShown is false', async () => {
      duoChatGlobalState.isShown = false;
      createComponent();
      await waitForPromises();

      expect(findSubscriptions().exists()).toBe(false);
    });

    it('calls addDuoChatMessage when @message is fired', () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      const mockMessage = {
        content: 'test message content',
        role: 'user',
      };

      findSubscriptions().vm.$emit('message', mockMessage);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), mockMessage);
    });

    describe('Subscription Component', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
        createComponent();
        performance.mark = jest.fn();
      });

      it('stops adding new messages when more chunks with the same request ID come in after the full message has already been received', () => {
        const requestId = '123';
        const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
        const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, requestId);
        const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

        // message chunk streaming in
        findSubscriptions().vm.$emit('message-stream', firstChunk);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

        // full message being sent
        findSubscriptions().vm.$emit('message', successResponse);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
        // another chunk with the same request ID
        findSubscriptions().vm.$emit('message-stream', secondChunk);
        // addDuoChatMessage should not be called since the full message was already sent
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
      });

      it('continues to invoke addDuoChatMessage when a new message chunk arrives with a distinct request ID, even after a complete message has been received', () => {
        const firstRequestId = '123';
        const secondRequestId = '124';
        const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, firstRequestId);
        const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, firstRequestId);
        const successResponse = GENERATE_MOCK_TANUKI_RES('', secondRequestId);

        // message chunk streaming in
        findSubscriptions().vm.$emit('message-stream', firstChunk);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

        // full message being sent
        findSubscriptions().vm.$emit('message', successResponse);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
        // another chunk with a new request ID
        findSubscriptions().vm.$emit('message-stream', secondChunk);
        // addDuoChatMessage should be called since the second chunk has a new requestId
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
      });
    });
  });

  describe('Resizable Dimensions', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = true;
      createComponent();
    });

    it('initializes `left` as undefined in dimensions before mounted lifecycle alters it', () => {
      const setDimensionsSpy = jest
        .spyOn(TanukiBotChatApp.methods, 'setDimensions')
        .mockImplementation(() => {});
      createComponent();
      expect(wrapper.vm.dimensions.left).toBe(null);
      setDimensionsSpy.mockRestore();
    });

    it('initializes dimensions correctly on mount', () => {
      createComponent();
      expect(wrapper.vm.width).toBe(400);
      expect(wrapper.vm.height).toBe(window.innerHeight);
      expect(wrapper.vm.maxWidth).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(window.innerHeight);
    });

    it('updates dimensions correctly when `chat-resize` event is emitted', async () => {
      const newWidth = 600;
      const newHeight = 500;
      const chat = findDuoChat();
      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(newWidth);
      expect(wrapper.vm.height).toBe(newHeight);
    });

    it('ensures dimensions do not exceed maxWidth or maxHeight', async () => {
      const newWidth = window.innerWidth + 100;
      const newHeight = window.innerHeight + 100;
      const chat = findDuoChat();

      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.height).toBe(window.innerHeight);
    });

    it('updates dimensions when the window is resized', async () => {
      createComponent();
      window.innerWidth = 1200;
      window.innerHeight = 800;

      window.dispatchEvent(new Event('resize'));
      await nextTick();

      expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(800);
    });

    it('renders DuoChat with shouldRenderResizable=false when duoChatDynamicDimension flag is false', () => {
      createComponent({ glFeatures: { duoChatDynamicDimension: false } });
      const duoChat = findDuoChat();
      expect(duoChat.exists()).toBe(true);
      expect(duoChat.props('shouldRenderResizable')).toBe(false);
    });

    it('renders DuoChat with shouldRenderResizable=true when duoChatDynamicDimension flag is true', () => {
      createComponent({ glFeatures: { duoChatDynamicDimension: true } });
      const duoChat = findDuoChat();
      expect(duoChat.exists()).toBe(true);
      expect(duoChat.props('shouldRenderResizable')).toBe(true);
    });
  });

  describe('multi-threaded chat functionality', () => {
    beforeEach(async () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();
    });

    describe('chat mutation selection and conversation type', () => {
      const mockThreadId = 'thread-123';
      const mockMessagesData = {
        data: {
          aiMessages: {
            nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
          },
        },
      };

      it('uses correct conversation type DUO_CHAT when sending a message and no active thread exists', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: 'gid://gitlab/Issue/1',
          projectId: null,
          conversationType: 'DUO_CHAT',
        });
      });

      it('uses correct conversation type DUO_CHAT when sending a message and active thread exists', async () => {
        threadQueryHandlerMock.mockResolvedValue(mockMessagesData);
        createComponent();

        findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
          conversationType: 'DUO_CHAT',
          threadId: mockThreadId,
        });
      });
    });

    describe('rootNamespaceId handling', () => {
      it('uses chatWithNamespaceMutation when rootNamespaceId is provided', async () => {
        createComponent({
          propsData: {
            userId: MOCK_USER_ID,
            resourceId: MOCK_RESOURCE_ID,
            rootNamespaceId: 'namespace-123',
          },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(chatWithNamespaceMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
          conversationType: 'DUO_CHAT',
          rootNamespaceId: 'namespace-123',
          threadId: undefined,
        });

        expect(chatMutationHandlerMock).not.toHaveBeenCalled();
      });

      it('uses chatMutation when rootNamespaceId is not provided', async () => {
        createComponent({
          propsData: {
            userId: MOCK_USER_ID,
            resourceId: MOCK_RESOURCE_ID,
          },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
          conversationType: 'DUO_CHAT',
          threadId: undefined,
        });

        expect(chatWithNamespaceMutationHandlerMock).not.toHaveBeenCalled();
      });
    });

    describe('thread handling', () => {
      describe('onThreadSelected', () => {
        const mockThreadId = 'thread-123';
        const mockMessagesData = {
          data: {
            aiMessages: {
              nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
            },
          },
        };

        it('loads messages for selected thread', async () => {
          threadQueryHandlerMock.mockResolvedValue(mockMessagesData);
          createComponent();
          await waitForPromises();

          findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
          await waitForPromises();

          expect(threadQueryHandlerMock).toHaveBeenCalledWith(
            expect.objectContaining({
              threadId: mockThreadId,
            }),
          );

          expect(actionSpies.setMessages).toHaveBeenCalledWith(
            expect.anything(),
            mockMessagesData.data.aiMessages.nodes,
          );
        });

        it('handles errors when loading thread messages', async () => {
          const error = new Error('Failed to load thread');
          threadQueryHandlerMock.mockRejectedValue(error);
          createComponent();
          await waitForPromises();

          findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
          await waitForPromises();

          expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              errors: [error.toString()],
            }),
          );
        });
      });

      describe('onNewChat', () => {
        it('resets chat state for new conversation', async () => {
          findDuoChat().vm.$emit('new-chat');
          await nextTick();

          const duoChat = findDuoChat();
          expect(duoChat.props('activeThreadId')).toBe('');
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(duoChat.props('multiThreadedView')).toBe('chat');
          expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
          expect(duoChat.props('canceledRequestIds')).toEqual([]);
        });

        it('clears duo chat commands when new chat is opened', async () => {
          duoChatGlobalState.commands = [{ question: 'test command' }];
          expect(duoChatGlobalState.commands).toHaveLength(1);

          findDuoChat().vm.$emit('new-chat');
          await nextTick();

          expect(duoChatGlobalState.commands).toHaveLength(0);
        });
      });

      describe('onBackToList', () => {
        it('returns to thread list view', async () => {
          conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);

          createComponent();
          const duoChat = findDuoChat();
          await waitForPromises();

          conversationThreadsQueryHandlerMock.mockReset();
          conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
          expect(conversationThreadsQueryHandlerMock).not.toHaveBeenCalled();
          findDuoChat().vm.$emit('back-to-list');
          await nextTick();
          await waitForPromises();

          expect(duoChat.props('multiThreadedView')).toBe('list');
          expect(duoChat.props('activeThreadId')).toBe('');
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(conversationThreadsQueryHandlerMock).toHaveBeenCalled();
        });
      });

      describe('onDeleteThread', () => {
        const mockThreadId = 'thread-123';

        it('successfully deletes thread', async () => {
          // Setup mock response that matches the mutation schema
          deleteConversationThreadMutationHandlerMock.mockResolvedValue({
            data: {
              deleteConversationThread: {
                success: true,
                errors: [],
              },
            },
          });

          findDuoChat().vm.$emit('delete-thread', mockThreadId);
          await nextTick();

          // Verify mutation was called with correct variables
          expect(deleteConversationThreadMutationHandlerMock).toHaveBeenCalledWith({
            input: { threadId: mockThreadId },
          });

          // Verify thread list is refetched after successful deletion
          expect(conversationThreadsQueryHandlerMock).toHaveBeenCalled();
        });
      });

      describe('thread list loading', () => {
        beforeEach(() => {
          duoChatGlobalState.isShown = true;
          conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
          threadQueryHandlerMock.mockResolvedValue({
            data: {
              aiMessages: {
                nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
              },
            },
          });
          createComponent();
        });

        it('does not auto-select thread when in list view', async () => {
          const duoChat = findDuoChat();

          duoChat.vm.$emit('back-to-list');
          await nextTick();
          await waitForPromises();
          expect(duoChat.props('activeThreadId')).toBe('');
          expect(duoChat.props('multiThreadedView')).toBe('list');
          expect(duoChat.props('threadList')).toEqual(MOCK_THREADS);
        });

        it('does not auto-select when there are no threads', async () => {
          conversationThreadsQueryHandlerMock.mockResolvedValue({
            data: {
              aiConversationThreads: {
                nodes: [],
                __typename: 'AiConversationsThreadConnection',
              },
            },
          });

          createComponent();

          const duoChat = findDuoChat();

          await nextTick();
          await waitForPromises();
          expect(duoChat.props('activeThreadId')).toBe('');
          expect(duoChat.props('threadList')).toHaveLength(0);
        });

        it('does not auto-select thread when command is from button', async () => {
          conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);

          duoChatGlobalState.commands = [{ question: 'Button command' }];

          createComponent();

          await waitForPromises();

          expect(wrapper.vm.activeThread).toBe(undefined);
        });
      });
    });
  });

  describe('aiConversationThreads query', () => {
    it.each`
      isShown  | shouldSkip | description
      ${false} | ${true}    | ${'when chat is hidden'}
      ${true}  | ${false}   | ${'when chat is shown'}
    `('skips query=$shouldSkip $description', async ({ isShown, shouldSkip }) => {
      duoChatGlobalState.isShown = isShown;
      createComponent();
      await waitForPromises();

      expect(conversationThreadsQueryHandlerMock).toHaveBeenCalledTimes(shouldSkip ? 0 : 1);
    });
  });

  describe('aiMessages query', () => {
    it.each`
      expectedType  | description
      ${'DUO_CHAT'} | ${'uses DUO_CHAT conversation type'}
    `('$description', async ({ expectedType }) => {
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      expect(queryHandlerMock).toHaveBeenCalledWith(
        expect.objectContaining({
          conversationType: expectedType,
        }),
      );
    });
  });

  describe('chatTitle functionality', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = true;
    });

    it('passes chatTitle prop to DuoChat component', async () => {
      const chatTitle = 'Custom Chat Title';
      createComponent({ propsData: { chatTitle } });
      await nextTick();
      expect(findDuoChat().props('title')).toBe(chatTitle);
    });

    it('passes null as title to DuoChat component when no chatTitle is provided', async () => {
      createComponent();
      await nextTick();
      expect(findDuoChat().props('title')).toBeNull();
    });

    it('updates DuoChat title when chatTitle prop changes', async () => {
      const localWrapper = shallowMountExtended(TanukiBotChatApp, {
        propsData: { chatTitle: 'Initial Title' },
        store: new Vuex.Store({ actions: actionSpies }),
        apolloProvider: createMockApollo([]),
      });
      duoChatGlobalState.isShown = true;
      await nextTick();
      expect(localWrapper.findComponent(DuoChat).props('title')).toBe('Initial Title');

      await localWrapper.setProps({ chatTitle: 'Updated Title' });
      expect(localWrapper.findComponent(DuoChat).props('title')).toBe('Updated Title');
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.isShown', () => {
      it('creates a new chat when Duo Chat is closed', async () => {
        duoChatGlobalState.isShown = true;
        createComponent();

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isShown = false;
        await nextTick();

        expect(onNewChatSpy).toHaveBeenCalled();
        expect(wrapper.vm.multithreadedView).toBe('chat');
      });

      it('does not create a new chat when Duo Chat is opened', async () => {
        duoChatGlobalState.isShown = false;
        createComponent();

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isShown = true;
        await nextTick();

        expect(onNewChatSpy).not.toHaveBeenCalled();
      });

      it('does not create a new thread when Duo Chat is opened with a command from button', async () => {
        duoChatGlobalState.isShown = false;
        duoChatGlobalState.commands = [{ question: 'Button command' }];

        createComponent();

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isShown = true;
        await nextTick();

        expect(onNewChatSpy).not.toHaveBeenCalled();

        onNewChatSpy.mockRestore();
      });
    });

    describe('duoChatGlobalState.commands', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
        createComponent();
      });

      afterEach(() => {
        duoChatGlobalState.commands = [];
      });

      it('calls onNewChat when new commands are added', async () => {
        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');
        duoChatGlobalState.commands = [{ question: 'test command' }];
        await nextTick();
        expect(onNewChatSpy).toHaveBeenCalled();
      });

      it('calls onSendChatPrompt with command values when new commands are added', async () => {
        const onSendChatPromptSpy = jest.spyOn(wrapper.vm, 'onSendChatPrompt');
        const commandData = {
          question: 'test command',
          variables: { foo: 'bar' },
          resourceId: 'custom-resource-id',
        };

        duoChatGlobalState.commands = [commandData];
        await nextTick();

        expect(onSendChatPromptSpy).toHaveBeenCalledWith(
          commandData.question,
          commandData.variables,
          commandData.resourceId,
        );
      });

      it('handles commands with only question property', async () => {
        const onSendChatPromptSpy = jest.spyOn(wrapper.vm, 'onSendChatPrompt');
        duoChatGlobalState.commands = [{ question: 'simple command' }];
        await nextTick();

        expect(onSendChatPromptSpy).toHaveBeenCalledWith('simple command', undefined, undefined);
      });

      it('processes only the first command if multiple commands exist', async () => {
        const onSendChatPromptSpy = jest.spyOn(wrapper.vm, 'onSendChatPrompt');
        duoChatGlobalState.commands = [
          { question: 'first command' },
          { question: 'second command' },
        ];
        await nextTick();

        expect(onSendChatPromptSpy).toHaveBeenCalledTimes(1);
        expect(onSendChatPromptSpy).toHaveBeenCalledWith('first command', undefined, undefined);
      });

      it('does nothing if commands array is empty', async () => {
        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');
        const onSendChatPromptSpy = jest.spyOn(wrapper.vm, 'onSendChatPrompt');

        duoChatGlobalState.commands = [];
        await nextTick();

        expect(onNewChatSpy).not.toHaveBeenCalled();
        expect(onSendChatPromptSpy).not.toHaveBeenCalled();
      });
    });
  });

  describe('duoAgenticModePreference toggle', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = true;
      jest.clearAllMocks();
    });

    describe('getter', () => {
      it.each`
        cookieValue | expected
        ${'true'}   | ${true}
        ${'false'}  | ${false}
        ${null}     | ${false}
        ${''}       | ${false}
      `('returns $expected when cookie value is $cookieValue', ({ cookieValue, expected }) => {
        getCookie.mockReturnValue(cookieValue);
        createComponent();

        expect(wrapper.vm.duoAgenticModePreference).toBe(expected);
        expect(getCookie).toHaveBeenCalledWith('duo_agentic_mode_on');
      });
    });

    describe('setter', () => {
      beforeEach(() => {
        getCookie.mockReturnValue('false');
        createComponent();
      });

      it.each`
        value    | description
        ${true}  | ${'true'}
        ${false} | ${'false'}
      `('calls setAgenticMode with $description and saveCookie=true', ({ value }) => {
        wrapper.vm.duoAgenticModePreference = value;

        expect(setAgenticMode).toHaveBeenCalledWith(value, true);
      });
    });
  });

  describe('Agentic Mode Toggle', () => {
    const findGlToggle = () => wrapper.findComponent(GlToggle);

    beforeEach(() => {
      duoChatGlobalState.isShown = true;
      getCookie.mockReturnValue('false');
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
          agenticAvailable: true,
        },
      });
    });

    it('renders the GlToggle component in subheader', () => {
      expect(findGlToggle().exists()).toBe(true);
    });

    it('passes correct props to GlToggle', () => {
      const toggle = findGlToggle();

      expect(toggle.props()).toMatchObject({
        label: 'Agentic mode (Beta)',
        labelPosition: 'left',
        value: false,
      });
    });

    it('binds duoAgenticModePreference to v-model', async () => {
      getCookie.mockReturnValue('true');
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
          agenticAvailable: true,
        },
      });
      await nextTick();

      expect(findGlToggle().props('value')).toBe(true);
    });

    it('calls setAgenticMode when toggle value changes', async () => {
      const toggle = findGlToggle();

      toggle.vm.$emit('change', true);
      await nextTick();

      expect(setAgenticMode).toHaveBeenCalledWith(true, true);
    });

    it('updates the toggle value when duoAgenticModePreference changes', async () => {
      getCookie.mockReturnValue('false');
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
          agenticAvailable: true, // Add this line
        },
      });
      await nextTick();

      expect(findGlToggle().props('value')).toBe(false);

      getCookie.mockReturnValue('true');
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
          agenticAvailable: true, // Add this line
        },
      });
      await nextTick();

      expect(findGlToggle().props('value')).toBe(true);
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = false;
        createComponent();
      });

      it('does not render the GlToggle component', () => {
        expect(findGlToggle().exists()).toBe(false);
      });
    });
  });

  describe('subheader template', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isShown = true;
    });

    it('renders subheader template with correct component', () => {
      const toggle = findDuoChat();
      expect(toggle.exists()).toBe(true);
    });
  });
});
