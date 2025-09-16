export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/20',
      environments: {
        __typename: 'EnvironmentConnection',
        nodes: [
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/56',
            name: 'project_env_development',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/55',
            name: 'project_env_production',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/57',
            name: 'project_env_staging',
          },
        ],
      },
    },
  },
};

export const mockGroupEnvironments = {
  data: {
    group: {
      __typename: 'Group',
      id: 'gid://gitlab/Group/96',
      environmentScopes: {
        __typename: 'CiGroupEnvironmentScopeConnection',
        nodes: [
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_development',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_production',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_staging',
          },
        ],
      },
    },
  },
};

export const mockProjectBranches = {
  data: {
    project: {
      id: 'gid://gitlab/Project/19',
      repository: {
        branchNames: ['dev', 'main', 'production', 'staging'],
        __typename: 'Repository',
      },
      __typename: 'Project',
    },
  },
};

export const mockProjectSecretsData = [
  {
    cursor: 'MQ',
    node: {
      branch: 'main',
      description: 'This is the first secret',
      environment: '*',
      name: 'SECRET_1',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    cursor: 'Mg',
    node: {
      branch: 'main',
      description: 'This is the second secret',
      environment: '*',
      name: 'SECRET_2',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    cursor: 'Mw',
    node: {
      branch: 'main',
      description: 'This is the third secret',
      environment: '*',
      name: 'SECRET_3',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    cursor: 'NA',
    node: {
      branch: 'main',
      description: 'This is the fourth secret',
      environment: '*',
      name: 'SECRET_4',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
  {
    cursor: 'NQ',
    node: {
      branch: 'main',
      description: 'This is the fifth secret',
      environment: '*',
      name: 'SECRET_5',
      project: {
        id: 'gid://gitlab/Project/19',
        __typename: 'Project',
      },
      __typename: 'ProjectSecret',
    },
    __typename: 'ProjectSecretEdge',
  },
];

export const mockSecretId = 44;

export const mockSecret = ({ customSecret } = {}) => ({
  __typename: 'Secret',
  id: mockSecretId,
  branch: 'main',
  description: 'This is a secret',
  environment: 'staging',
  name: 'APP_PWD',
  ...customSecret,
});

export const mockEmptySecrets = {
  data: {
    projectSecrets: {
      edges: [],
      pageInfo: {
        endCursor: null,
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        __typename: 'PageInfo',
      },
      __typename: 'ProjectSecretConnection',
    },
  },
};

export const mockProjectSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    projectSecretCreate: {
      errors,
      __typename: 'ProjectSecretCreatePayload',
      projectSecret: {
        name: 'APP_PWD',
        description: 'This is a secret',
        ...customSecret,
        __typename: 'ProjectSecret',
      },
    },
  },
});

export const mockProjectUpdateSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    projectSecretUpdate: {
      errors,
      __typename: 'ProjectSecretUpdatePayload',
      projectSecret: {
        name: 'APP_PWD',
        description: 'This is an edited secret',
        ...customSecret,
        __typename: 'ProjectSecret',
      },
    },
  },
});

export const mockProjectSecretQueryResponse = ({ customSecret } = {}) => ({
  data: {
    projectSecret: {
      __typename: 'ProjectSecret',
      ...mockSecret(),
      ...customSecret,
    },
  },
});

export const secretManagerStatusResponse = (status) => {
  return {
    data: {
      projectSecretsManager: {
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
  };
};

export const mockDeleteProjectSecretResponse = {
  data: {
    projectSecretDelete: {
      errors: [],
      __typename: 'ProjectSecretDeletePayload',
    },
  },
};

export const mockDeleteProjectSecretErrorResponse = {
  data: {
    projectSecretDelete: {
      errors: ['This is an API error.'],
      __typename: 'ProjectSecretDeletePayload',
    },
  },
};
