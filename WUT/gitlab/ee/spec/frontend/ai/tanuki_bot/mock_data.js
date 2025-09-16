import { MESSAGE_TYPES, SOURCE_TYPES } from 'ee/ai/tanuki_bot/constants';
import { PROMO_URL } from '~/constants';

export const MOCK_SLASH_COMMANDS = {
  data: {
    aiSlashCommands: [
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
    ],
  },
};

export const MOCK_SOURCE_TYPES = {
  HANDBOOK: {
    title: 'GitLab Handbook',
    source_type: SOURCE_TYPES.HANDBOOK.value,
    source_url: `${PROMO_URL}/handbook/`,
  },
  DOC: {
    stage: 'Mock Stage',
    group: 'Mock Group',
    source_type: SOURCE_TYPES.DOC.value,
    source_url: `${PROMO_URL}/company/team/`,
  },
  BLOG: {
    date: '2023-04-21',
    author: 'Test User',
    source_type: SOURCE_TYPES.BLOG.value,
    source_url: `${PROMO_URL}/blog/`,
  },
};

export const MOCK_SOURCES = Object.values(MOCK_SOURCE_TYPES);

export const MOCK_TANUKI_MESSAGE = {
  id: '123',
  content: 'Tanuki Bot message',
  contentHtml: '<p>Tanuki Bot message</p>',
  role: MESSAGE_TYPES.TANUKI,
  extras: {
    sources: MOCK_SOURCES,
    hasFeedback: false,
  },
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
};

export const MOCK_USER_MESSAGE = {
  id: '456',
  content: 'User message',
  contentHtml: '<p>User message</p>',
  role: MESSAGE_TYPES.USER,
  requestId: '987',
  errors: [],
  timestamp: '2021-04-21T12:00:00.000Z',
  extras: null,
};

export const MOCK_FAILING_USER_MESSAGE = {
  content: 'User message that caused an error',
  role: MESSAGE_TYPES.USER,
  requestId: null,
  errors: ['Oh darn, you are not allowed to use AI!'],
};

export const MOCK_CHUNK_MESSAGE = (content = '', chunkId = 0, requestId = 1) => {
  return {
    id: '611363bc-c75a-44e2-80cd-f22ab5e665be',
    requestId,
    content,
    errors: [],
    role: 'ASSISTANT',
    timestamp: '2024-05-29T17:17:06Z',
    type: null,
    chunkId,
    extras: {
      sources: null,
    },
  };
};

export const GENERATE_MOCK_TANUKI_RES = (
  body = JSON.stringify(MOCK_TANUKI_MESSAGE),
  requestId = '987',
) => {
  return {
    id: '123',
    content: body,
    contentHtml: `<p>${body}</p>`,
    errors: [],
    requestId,
    role: MOCK_TANUKI_MESSAGE.role,
    timestamp: '2021-04-21T12:00:00.000Z',
    type: null,
    chunkId: null,
    extras: null,
  };
};

export const MOCK_TANUKI_SUCCESS_RES = GENERATE_MOCK_TANUKI_RES();

export const MOCK_TANUKI_ERROR_RES = (body = JSON.stringify(MOCK_TANUKI_MESSAGE)) => {
  return {
    data: {
      aiCompletionResponse: {
        id: '123',
        content: body,
        contentHtml: body,
        errors: ['error'],
      },
    },
  };
};

export const MOCK_CHAT_CACHED_MESSAGES_RES = {
  data: {
    aiMessages: {
      nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
    },
  },
};

export const MOCK_TANUKI_BOT_MUTATATION_RES = {
  data: { aiAction: { errors: [], requestId: '123', threadId: 'thread-123' } },
};

export const MOCK_USER_ID = 'gid://gitlab/User/1';
export const MOCK_CLIENT_SUBSCRIPTION_ID = '123';
export const MOCK_RESOURCE_ID = 'gid://gitlab/Issue/1';

export const MOCK_THREADS = [
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/121',
    lastUpdatedAt: '2025-02-14T15:26:11Z',
    createdAt: '2025-02-14T15:14:02Z',
    conversationType: 'DUO_CHAT',
    title: 'ddd',
  },
  {
    __typename: 'AiConversationsThread',
    id: 'gid://gitlab/Ai::Conversation::Thread/120',
    lastUpdatedAt: '2025-02-14T15:13:57Z',
    createdAt: '2025-02-14T15:13:57Z',
    conversationType: 'DUO_CHAT',
    title: null,
  },
];

export const MOCK_THREADS_RESPONSE = {
  data: {
    aiConversationThreads: {
      __typename: 'AiConversationsThreadConnection',
      nodes: MOCK_THREADS,
      pageInfo: {
        __typename: 'PageInfo',
        endCursor:
          'eyJsYXN0X3VwZGF0ZWRfYXQiOiIyMDI1LTAyLTE0IDE1OjEzOjU3LjkzMDgzNDAwMCArMDAwMCIsImlkIjoiMTIwIn0',
        hasNextPage: false,
      },
    },
  },
};

export const MOCK_AI_RESOURCE_DATA = JSON.stringify({
  type: 'issue',
  id: 789,
  title: 'Test Issue',
});
export const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'What are the main points from this MR discussion?',
        'What changes were requested by reviewers?',
        'What concerns remain unresolved in this MR?',
        'What changed in this diff?',
      ],
      aiResourceData: MOCK_AI_RESOURCE_DATA,
    },
  },
};
