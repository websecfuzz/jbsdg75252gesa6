export const accessLevelsMockResponse = [
  {
    __typename: 'PushAccessLevelEdge',
    node: {
      __typename: 'PushAccessLevel',
      accessLevel: 40,
      accessLevelDescription: 'Jona Langworth',
      group: null,
      user: {
        __typename: 'UserCore',
        id: '123',
      },
    },
  },
  {
    __typename: 'PushAccessLevelEdge',
    node: {
      __typename: 'PushAccessLevel',
      accessLevel: 40,
      accessLevelDescription: 'Maintainers',
      group: null,
      user: null,
    },
  },
];

export const branchRulesMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      branchRules: {
        __typename: 'BranchRuleConnection',
        nodes: [
          {
            name: 'main',
            id: 'gid://gitlab/Projects/BranchRule/1',
            isDefault: true,
            matchingBranchesCount: 1,
            branchProtection: {
              allowForcePush: true,
              codeOwnerApprovalRequired: true,
              mergeAccessLevels: {
                edges: [],
                __typename: 'MergeAccessLevelConnection',
              },
              pushAccessLevels: {
                edges: accessLevelsMockResponse,
                __typename: 'PushAccessLevelConnection',
              },
            },
            approvalRules: {
              nodes: [{ id: 1 }],
              __typename: 'ApprovalProjectRuleConnection',
            },
            externalStatusChecks: {
              nodes: [{ id: 1 }, { id: 2 }],
              __typename: 'ExternalStatusCheckConnection',
            },
            __typename: 'BranchRule',
          },
          {
            name: 'test-*',
            id: 'gid://gitlab/Projects/BranchRule/2',
            isDefault: false,
            matchingBranchesCount: 2,
            branchProtection: {
              allowForcePush: false,
              codeOwnerApprovalRequired: false,
              mergeAccessLevels: {
                edges: [],
                __typename: 'MergeAccessLevelConnection',
              },
              pushAccessLevels: {
                edges: [],
                __typename: 'PushAccessLevelConnection',
              },
            },
            approvalRules: {
              nodes: [],
              __typename: 'ApprovalProjectRuleConnection',
            },
            externalStatusChecks: {
              nodes: [],
              __typename: 'ExternalStatusCheckConnection',
            },
            __typename: 'BranchRule',
          },
        ],
      },
    },
  },
};

export const predefinedBranchRulesMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      branchRules: {
        __typename: 'BranchRuleConnection',
        nodes: [
          {
            name: 'All branches',
            id: 'gid://gitlab/Projects::AllBranchesRule/7',
            isDefault: false,
            matchingBranchesCount: 12,
            branchProtection: null,
            externalStatusChecks: {
              nodes: [],
              __typename: 'ExternalStatusCheckConnection',
            },
            approvalRules: {
              nodes: [
                {
                  id: '3',
                  __typename: 'ApprovalProjectRule',
                },
                {
                  id: '4',
                  __typename: 'ApprovalProjectRule',
                },
              ],
              __typename: 'ApprovalProjectRuleConnection',
            },
            __typename: 'BranchRule',
          },
          {
            name: 'All protected branches',
            id: 'gid://gitlab/Projects::AllBranchesRule/6',
            isDefault: false,
            matchingBranchesCount: 14,
            branchProtection: null,
            externalStatusChecks: {
              nodes: [],
              __typename: 'ExternalStatusCheckConnection',
            },
            approvalRules: {
              nodes: [
                {
                  id: '5',
                  __typename: 'ApprovalProjectRule',
                },
                {
                  id: '6',
                  __typename: 'ApprovalProjectRule',
                },
              ],
              __typename: 'ApprovalProjectRuleConnection',
            },
            __typename: 'BranchRule',
          },
        ],
      },
    },
  },
};

export const appProvideMock = {
  projectPath: 'some/project/path',
  branchRulesPath: 'settings/repository/branch_rules',
};

export const branchRuleProvideMock = {
  branchRulesPath: 'settings/repository/branch_rules',
};

export const createBranchRuleMockResponse = {
  data: {
    branchRuleCreate: {
      errors: [],
      branchRule: {
        name: '*dkd',
        __typename: 'BranchRule',
      },
      __typename: 'BranchRuleCreatePayload',
    },
  },
};

export const branchRulePropsMock = {
  name: 'main',
  isDefault: true,
  matchingBranchesCount: 1,
  branchProtection: {
    allowForcePush: true,
    codeOwnerApprovalRequired: true,
    pushAccessLevels: {
      edges: accessLevelsMockResponse,
    },
  },
  approvalRulesTotal: 1,
  statusChecksTotal: 2,
  projectPath: 'some/project/path',
};

export const protectableBranches = ['make-release-umd-bundle', 'main', 'v2.x'];

export const protectableBranchesMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      protectableBranches,
      __typename: 'Project',
    },
  },
};
