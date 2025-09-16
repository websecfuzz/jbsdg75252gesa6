const TYPENAME_AI_CATALOG_ITEM = 'AiCatalogItem';
const TYPENAME_AI_CATALOG_ITEM_CONNECTION = 'AiCatalogItemConnection';
const TYPENAME_PROJECT = 'Project';

const mockProject = {
  id: 'gid://gitlab/Project/1',
  __typename: TYPENAME_PROJECT,
};

const mockAgentFactory = (overrides = {}) => ({
  id: 'gid://gitlab/Ai::Catalog::Item/1',
  name: 'Test AI Agent 1',
  itemType: 'AGENT',
  description: 'A helpful AI assistant for testing purposes',
  createdAt: '2024-01-15T10:30:00Z',
  __typename: TYPENAME_AI_CATALOG_ITEM,
  ...overrides,
});

export const mockAgent = mockAgentFactory();

export const mockAgents = [
  mockAgent,
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Test AI Agent 2',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
  }),
  mockAgentFactory({
    id: 'gid://gitlab/Ai::Catalog::Item/3',
    name: 'Test AI Agent 3',
    description: 'Another AI assistant',
    createdAt: '2024-02-10T14:20:00Z',
  }),
];

export const mockAgentProject = mockAgentFactory({
  project: mockProject,
});

export const mockCatalogItemsResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockAgents,
      __typename: TYPENAME_AI_CATALOG_ITEM_CONNECTION,
    },
  },
};

export const mockCatalogItemResponse = {
  data: {
    aiCatalogItem: mockAgentProject,
  },
};

export const mockCatalogItemNullResponse = {
  data: {
    aiCatalogItem: null,
  },
};

export const mockCreateAiCatalogAgentSuccessMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: [],
      item: mockAgentProject,
    },
  },
};

export const mockCreateAiCatalogAgentErrorMutation = {
  data: {
    aiCatalogAgentCreate: {
      errors: ['Some error'],
      item: null,
    },
  },
};
