import { AgenticDuoChat, AgenticToolApprovalFlow } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { setAgenticMode } from 'ee/ai/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import DuoAgenticChatApp from 'ee/ai/duo_agentic_chat/components/app.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
  DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
} from 'ee/ai/constants';
import { WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import { createWebSocket, closeSocket } from '~/lib/utils/websocket_utils';
import { getCookie } from '~/lib/utils/common_utils';

// Mock the WebSocket utils - completely isolated
const mockSocketManager = {
  connect: jest.fn(),
  send: jest.fn(),
  close: jest.fn(),
  isConnected: jest.fn().mockReturnValue(true),
  getState: jest.fn().mockReturnValue('OPEN'),
};

jest.mock('~/lib/utils/websocket_utils', () => ({
  createWebSocket: jest.fn(() => mockSocketManager),
  parseMessage: jest.fn(async (event) => {
    const data = typeof event.data === 'string' ? event.data : await event.data.text();
    return JSON.parse(data);
  }),
  closeSocket: jest.fn(),
}));

const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
const MOCK_RESOURCE_ID = 'gid://gitlab/Resource/789';
const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflow/456';
const MOCK_USER_MESSAGE = {
  content: 'How can I optimize my CI pipeline?',
  role: 'user',
  requestId: `${MOCK_WORKFLOW_ID}-0`,
};
const MOCK_AI_RESOURCE_DATA = JSON.stringify({ type: 'issue', id: 789, title: 'Test Issue' });
const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'How can I optimize my CI pipeline?',
        'What are best practices for merge requests?',
        'How do I set up a workflow for my project?',
        'What are the advantages of using GitLab CI/CD?',
      ],
      aiResourceData: MOCK_AI_RESOURCE_DATA,
    },
  },
};
const MOCK_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    aiDuoWorkflowCreate: {
      workflow: {
        id: MOCK_WORKFLOW_ID,
      },
      errors: [],
    },
  },
};

const expectedAdditionalContext = [
  {
    content: MOCK_AI_RESOURCE_DATA,
    category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
    metadata: JSON.stringify({}),
  },
];

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
}));

jest.mock('ee/ai/utils', () => {
  const actualUtils = jest.requireActual('ee/ai/utils');

  return {
    __esModule: true,
    ...actualUtils,
    setAgenticMode: jest.fn(),
  };
});

describe('Duo Agentic Chat', () => {
  let wrapper;

  const actionSpies = {
    addDuoChatMessage: jest.fn(),
    setMessages: jest.fn(),
    setLoading: jest.fn(),
  };

  const duoWorkflowMutationHandlerMock = jest
    .fn()
    .mockResolvedValue(MOCK_WORKFLOW_MUTATION_RESPONSE);
  const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);

  const findDuoChat = () => wrapper.findComponent(AgenticDuoChat);
  const findToolApprovalFlow = () => wrapper.findComponent(AgenticToolApprovalFlow);
  const getLastSocketCall = () => {
    const [, socketCallbacks] = createWebSocket.mock.calls[0];
    return socketCallbacks;
  };

  const createComponent = ({
    initialState = {},
    propsData = { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
    data = {},
  } = {}) => {
    const store = new Vuex.Store({
      actions: actionSpies,
      state: {
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [duoWorkflowMutation, duoWorkflowMutationHandlerMock],
      [getAiChatContextPresets, contextPresetsQueryHandlerMock],
    ]);

    if (duoChatGlobalState.isAgenticChatShown !== false) {
      duoChatGlobalState.isAgenticChatShown = true;
    }

    wrapper = shallowMountExtended(DuoAgenticChatApp, {
      store,
      apolloProvider,
      propsData,
      data() {
        return data;
      },
    });
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.isAgenticChatShown = false;
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = true;
      });

      it('renders the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('renders the AgenticToolApprovalFlow component', () => {
        expect(findToolApprovalFlow().exists()).toBe(true);
      });

      it('calls the context presets GraphQL query when component loads', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          url: 'http://test.host/',
          questionCount: 4,
        });
      });

      it('passes context presets to AgenticDuoChat component as predefinedPrompts', async () => {
        await waitForPromises();
        expect(findDuoChat().props('predefinedPrompts')).toEqual(
          MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
        );
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isAgenticChatShown = false;
      });

      it('does not render the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(false);
      });

      it('does not call the context presets GraphQL query', () => {
        expect(contextPresetsQueryHandlerMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isAgenticChatShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isAgenticChatShown).toBe(false);
        expect(findDuoChat().exists()).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'resets chat state when "%s" command is sent',
        async (command) => {
          createComponent();
          wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

          findDuoChat().vm.$emit('send-chat-prompt', command);
          await nextTick();

          expect(wrapper.vm.workflowId).toBe(null);
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        },
      );

      it('creates a new workflow when sending a prompt for the first time', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(duoWorkflowMutationHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          goal: MOCK_USER_MESSAGE.content,
          workflowDefinition: 'chat',
          agentPrivileges: [2, 3],
          preApprovedAgentPrivileges: [2],
        });

        expect(createWebSocket).toHaveBeenCalledWith('/api/v4/ai/duo_workflows/ws', {
          onMessage: expect.any(Function),
          onError: expect.any(Function),
          onClose: expect.any(Function),
        });

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: expect.stringContaining('-'),
          }),
        );
      });

      it('sets loading to true when sending a prompt', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), true);
      });

      it('does not create a new workflow if one already exists', async () => {
        wrapper.vm.workflowId = '456';

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(duoWorkflowMutationHandlerMock).not.toHaveBeenCalled();
        expect(createWebSocket).toHaveBeenCalledWith(
          '/api/v4/ai/duo_workflows/ws',
          expect.any(Object),
        );
      });

      it('sends the correct start request to WebSocket when connected', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        const expectedStartRequest = {
          startRequest: {
            workflowID: '456',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            goal: MOCK_USER_MESSAGE.content,
            approval: {},
            additionalContext: expectedAdditionalContext,
          },
        };

        expect(mockSocketManager.connect).toHaveBeenCalledWith(expectedStartRequest);
      });
    });

    describe('WebSocket message handling', () => {
      let socketCall;

      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = '456';
        socketCall = getLastSocketCall();
      });

      it('processes messages from the WebSocket and updates the UI', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  { content: 'Hello, how can I help?', message_type: 'agent' },
                  {
                    content: 'I can assist with optimizing your CI pipeline.',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'completed',
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          expect.arrayContaining([
            expect.objectContaining({
              content: 'Hello, how can I help?',
              message_type: 'assistant',
              role: 'assistant',
              requestId: '456-0',
            }),
            expect.objectContaining({
              content: 'I can assist with optimizing your CI pipeline.',
              message_type: 'assistant',
              role: 'assistant',
              requestId: '456-1',
            }),
          ]),
        );

        expect(mockSocketManager.send).toHaveBeenCalledWith({
          actionResponse: { requestID: 'request-id-1' },
        });
      });

      it('handles tool approval flow', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need to run a command.',
                    role: 'assistant',
                    tool_info: {
                      name: 'run_command',
                      args: { command: 'ls -la' },
                    },
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(findToolApprovalFlow().props('visible')).toBe(true);
        expect(findToolApprovalFlow().props('toolDetails')).toEqual({
          name: 'run_command',
          parameters: { command: 'ls -la' },
        });

        // Should NOT send actionResponse when waiting for approval
        expect(mockSocketManager.send).not.toHaveBeenCalledWith({
          actionResponse: { requestID: 'request-id-1' },
        });
      });

      it('handles tool messages in the chat log', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Using tool to search issues',
                    message_type: 'tool',
                    tool_info: { name: 'search_issues' },
                  },
                ],
              },
            }),
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          expect.arrayContaining([
            expect.objectContaining({
              content: 'Using tool to search issues',
              message_type: 'tool',
              role: 'tool',
              tool_info: { name: 'search_issues' },
              requestId: '456-0',
            }),
          ]),
        );

        expect(mockSocketManager.send).toHaveBeenCalledWith({
          actionResponse: { requestID: 'request-id-2' },
        });
      });

      it.each([
        {
          messageType: 'request',
          expectedRole: 'assistant',
          expectedMessageType: 'assistant',
          description: 'handles request message type correctly',
        },
        {
          messageType: 'agent',
          expectedRole: 'assistant',
          expectedMessageType: 'assistant',
          description: 'handles agent message type correctly',
        },
        {
          messageType: 'special',
          expectedRole: 'special',
          expectedMessageType: 'special',
          description: 'handles special message type correctly',
        },
      ])('$description', async ({ messageType, expectedRole, expectedMessageType }) => {
        const mockCheckpointData = {
          requestID: 'request-id-3',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Processing your request',
                    message_type: messageType,
                    additional_data: { some: 'data' },
                  },
                ],
              },
            }),
            status: 'completed',
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          expect.arrayContaining([
            expect.objectContaining({
              content: 'Processing your request',
              message_type: expectedMessageType,
              role: expectedRole,
              additional_data: { some: 'data' },
              requestId: '456-0',
            }),
          ]),
        );

        expect(mockSocketManager.send).toHaveBeenCalledWith({
          actionResponse: { requestID: 'request-id-3' },
        });
      });

      it('sets loading to false when workflow status is INPUT_REQUIRED', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-4',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Please provide more information',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });

        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        expect(mockSocketManager.send).toHaveBeenCalledWith({
          actionResponse: { requestID: 'request-id-4' },
        });
      });

      it('handles errors from WebSocket', () => {
        socketCall.onError();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: ['Error: Unable to connect to workflow service. Please try again.'],
          }),
        );
      });
    });

    describe('@chat-cancel', () => {
      it('cancels the active connection and resets state', async () => {
        wrapper.vm.workflowId = '456';
        wrapper.vm.socketManager = mockSocketManager;

        findDuoChat().vm.$emit('chat-cancel');
        await nextTick();

        expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);
        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        expect(wrapper.vm.workflowId).toBe(null);
        expect(wrapper.vm.socketManager).toBe(null);
      });
    });

    describe('@new-chat', () => {
      it('resets chat state for new conversation', async () => {
        wrapper.vm.workflowId = '456';
        wrapper.vm.socketManager = mockSocketManager;

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(wrapper.vm.workflowId).toBe(null);
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(actionSpies.setLoading).toHaveBeenCalledWith(expect.anything(), false);
        expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);
      });
    });

    describe('tool approval flow', () => {
      let socketCall;

      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        socketCall = getLastSocketCall();

        // Set up pending tool call by simulating a message that requires approval
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need to run a command.',
                    role: 'assistant',
                    tool_info: {
                      name: 'run_command',
                      args: { command: 'ls -la' },
                    },
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_TOOL_CALL_APPROVAL_REQUIRED,
          },
        };

        await socketCall.onMessage({
          data: {
            text: () => Promise.resolve(JSON.stringify(mockCheckpointData)),
          },
        });
      });

      it('handles tool approval', async () => {
        findToolApprovalFlow().vm.$emit('approve');
        await nextTick();

        const expectedStartRequest = {
          startRequest: {
            workflowID: '456',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            goal: '',
            approval: { approval: {} },
            additionalContext: expectedAdditionalContext,
          },
        };

        expect(mockSocketManager.connect).toHaveBeenCalledWith(expectedStartRequest);
      });

      it('handles tool denial', async () => {
        const denyMessage = 'I do not approve this action';
        findToolApprovalFlow().vm.$emit('deny', denyMessage);
        await nextTick();

        const expectedStartRequest = {
          startRequest: {
            workflowID: '456',
            clientVersion: '1.0',
            workflowDefinition: 'chat',
            goal: '',
            approval: {
              approval: undefined,
              rejection: { message: denyMessage },
            },
            additionalContext: expectedAdditionalContext,
          },
        };

        expect(mockSocketManager.connect).toHaveBeenCalledWith(expectedStartRequest);
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Failed to fetch resources';

    it('handles errors from the context presets query', async () => {
      contextPresetsQueryHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      expect(findDuoChat().exists()).toBe(true);
      expect(findDuoChat().props('predefinedPrompts')).toEqual([]);
    });

    it('handles workflow mutation errors', async () => {
      duoWorkflowMutationHandlerMock.mockRejectedValue(new Error(errorText));
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });
  });

  describe('Resizable Dimensions', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
    });

    it('initializes dimensions correctly on mount', () => {
      expect(wrapper.vm.width).toBe(550);
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
      const originalInnerWidth = window.innerWidth;
      const originalInnerHeight = window.innerHeight;

      try {
        window.innerWidth = 1200;
        window.innerHeight = 800;

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
        expect(wrapper.vm.maxHeight).toBe(800);
      } finally {
        window.innerWidth = originalInnerWidth;
        window.innerHeight = originalInnerHeight;
      }
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.isAgenticChatShown', () => {
      it('creates a new chat when Duo Chat is closed', async () => {
        duoChatGlobalState.isAgenticChatShown = true;
        createComponent();
        wrapper.vm.workflowId = '456';

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isAgenticChatShown = false;
        await nextTick();

        expect(onNewChatSpy).toHaveBeenCalled();
        expect(wrapper.vm.workflowId).toBe(null);
      });

      it('does not create a new chat when Duo Chat is opened', async () => {
        duoChatGlobalState.isAgenticChatShown = false;
        createComponent();

        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        duoChatGlobalState.isAgenticChatShown = true;
        await nextTick();

        expect(onNewChatSpy).not.toHaveBeenCalled();
      });
    });
  });

  describe('Socket cleanup', () => {
    it('cleans up socket on component destroy', () => {
      duoChatGlobalState.isAgenticChatShown = true;
      createComponent();
      wrapper.vm.socketManager = mockSocketManager;

      wrapper.destroy();

      expect(closeSocket).toHaveBeenCalledWith(mockSocketManager);
    });
  });

  describe('duoAgenticModePreference toggle', () => {
    beforeEach(() => {
      duoChatGlobalState.isAgenticChatShown = true;
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
      duoChatGlobalState.isAgenticChatShown = true;
      getCookie.mockReturnValue('false');
      createComponent();
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
      createComponent();
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
      createComponent();
      await nextTick();

      expect(findGlToggle().props('value')).toBe(false);

      getCookie.mockReturnValue('true');
      createComponent();
      await nextTick();

      expect(findGlToggle().props('value')).toBe(true);
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isAgenticChatShown = false;
        createComponent();
      });

      it('does not render the GlToggle component', () => {
        expect(findGlToggle().exists()).toBe(false);
      });
    });
  });
});
