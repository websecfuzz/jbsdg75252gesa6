export const createAiAgentsResponses = {
  success: {
    data: {
      aiAgentCreate: {
        agent: {
          id: 'gid://gitlab/Ai::Agent/1',
          routeId: 2,
        },
        errors: [],
      },
    },
  },
  validationFailure: {
    data: {
      aiAgentCreate: {
        agent: null,
        errors: ['Name is invalid', "Name can't be blank"],
      },
    },
  },
};

export const updateAiAgentsResponses = {
  success: {
    data: {
      aiAgentUpdate: {
        agent: {
          id: 'gid://gitlab/Ai::Agent/1',
          routeId: 2,
          name: 'New name',
          latestVersion: {
            id: 'gid://gitlab/Ai::AgentVersion/1',
            prompt: 'my prompt',
            model: 'default',
          },
        },
        errors: [],
      },
    },
  },
  validationFailure: {
    data: {
      aiAgentUpdate: {
        agent: null,
        errors: ['Name is invalid'],
      },
    },
  },
};

export const listAiAgentsResponses = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Ai::Agent/1',
            routeId: 2,
            name: 'agent-1',
            versions: [
              {
                id: 'gid://gitlab/Ai::AgentVersion/1',
                prompt: 'example prompt',
                model: 'default',
              },
            ],
          },
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: 'eyJpZCI6IjEwIn0',
          endCursor: 'eyJpZCI6IjEifQ',
          __typename: 'PageInfo',
        },
      },
    },
  },
};

export const listAiAgentsEmptyResponses = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiAgents: {
        nodes: [],
      },
    },
  },
};

export const getLatestAiAgentResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiAgent: {
        id: 'gid://gitlab/Ai::Agent/1',
        routeId: 2,
        name: 'agent-1',
        versions: [
          {
            id: 'gid://gitlab/Ai::AgentVersion/1',
            prompt: 'example prompt',
            model: 'default',
          },
        ],
        latestVersion: {
          id: 'gid://gitlab/Ai::AgentVersion/1',
          prompt: 'example prompt',
          model: 'default',
        },
      },
    },
  },
};

export const getLatestAiAgentNotFoundResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      aiAgent: null,
    },
  },
};

export const getLatestAiAgentErrorResponse = {
  errors: [
    {
      message: 'An error has occurred when loading the agent.',
    },
  ],
};

export const destroyAiAgentsResponses = {
  success: {
    data: {
      aiAgentDestroy: {
        message: 'AI Agent was successfully deleted',
        errors: [],
      },
    },
  },
  error: {
    data: {
      aiAgentDestroy: {
        message: null,
        errors: ['AI Agent not found'],
      },
    },
  },
};
