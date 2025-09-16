// Mocks for child components

export const usersMock = [
  {
    id: '123',
    username: 'usr1',
    webUrl: 'http://test.test/usr1',
    name: 'User 1',
    avatarUrl: 'http://test.test/avt1.png',
  },
  {
    id: '456',
    username: 'usr2',
    webUrl: 'http://test.test/usr2',
    name: 'User 2',
    avatarUrl: 'http://test.test/avt2.png',
  },
  {
    id: '789',
    username: 'usr3',
    webUrl: 'http://test.test/usr3',
    name: 'User 3',
    avatarUrl: 'http://test.test/avt3.png',
  },
  {
    id: '987',
    username: 'usr4',
    webUrl: 'http://test.test/usr4',
    name: 'User 4',
    avatarUrl: 'http://test.test/avt4.png',
  },
  {
    id: '654',
    username: 'usr5',
    webUrl: 'http://test.test/usr5',
    name: 'User 5',
    avatarUrl: 'http://test.test/avt5.png',
  },
];

export const groupsMock = [{ name: 'test_group_1' }, { name: 'test_group_2' }];

const accessLevelsMock = [40];

const deployKeysMock = [
  {
    id: '123123',
    title: 'Deploy key 1',
    user: {
      name: 'User 1',
    },
  },
];

const approvalsRequired = 3;

export const approvalRulesMock = [
  {
    __typename: 'ApprovalProjectRule',
    id: '123',
    name: 'test',
    type: 'REGULAR',
    eligibleApprovers: { nodes: usersMock },
    approvalsRequired,
  },
];

export const statusChecksRulesMock = [
  {
    __typename: 'ExternalStatusCheck',
    id: '123',
    name: 'test',
    externalUrl: 'https://test.test',
    hmac: false,
  },
  {
    __typename: 'ExternalStatusCheck',
    id: '456',
    name: 'test 2',
    externalUrl: 'https://test2.test2',
    hmac: true,
  },
];

export const protectionPropsMock = {
  header: 'Allowed to push and merge',
  headerLinkTitle: 'Manage in protected branches',
  headerLinkHref: 'protected/branches',
  roles: accessLevelsMock,
  users: usersMock,
  groups: groupsMock,
  statusChecks: statusChecksRulesMock,
};

export const protectionRowPropsMock = {
  title: 'Test title',
  users: usersMock,
  accessLevels: accessLevelsMock,
  approvalsRequired,
  statusCheckUrl: statusChecksRulesMock[0].externalUrl,
};

// Mocks for getBranchRulesDetails

const maintainersAccessLevel = {
  accessLevel: 40,
  accessLevelDescription: 'Maintainers',
  group: null,
  user: null,
};

const userAccessLevel = {
  accessLevel: 40,
  accessLevelDescription: 'Jona Langworth',
  group: null,
  user: {
    __typename: 'UserCore',
    id: '123',
    webUrl: 'test.com',
    name: 'peter',
    username: 'peter',
    avatarUrl: 'test.com/user.png',
    src: 'test.com/user.png',
  },
};

const pushAccessLevelEdges = [
  {
    __typename: 'PushAccessLevelEdge',
    node: {
      __typename: 'PushAccessLevel',
      deployKey: null,
      ...userAccessLevel,
    },
  },
  {
    __typename: 'PushAccessLevelEdge',
    node: {
      __typename: 'PushAccessLevel',
      deployKey: null,
      ...maintainersAccessLevel,
    },
  },
];

const mergeAccessLevelEdges = [
  {
    __typename: 'MergeAccessLevelEdge',
    node: {
      __typename: 'MergeAccessLevel',
      ...userAccessLevel,
    },
  },
  {
    __typename: 'MergeAccessLevelEdge',
    node: {
      __typename: 'MergeAccessLevel',
      ...maintainersAccessLevel,
    },
  },
];

export const matchingBranchesCount = 3;

export const squashOptionMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/6',
      __typename: 'Project',
      branchRules: {
        __typename: 'BranchRuleConnection',
        nodes: [
          {
            __typename: 'BranchRule',
            name: 'main',
            id: 'gid://gitlab/Projects/BranchRule/1',
            squashOption: {
              option: 'Encourage',
              helpText: 'Checkbox is visible and selected by default.',
              __typename: 'SquashOption',
            },
          },
          {
            __typename: 'BranchRule',
            name: '*',
            id: 'gid://gitlab/Projects/BranchRule/2',
            squashOption: null,
          },
        ],
      },
    },
  },
};

export const editSquashOptionMockResponse = {
  data: {
    branchRuleSquashOptionUpdate: {
      errors: [],
      squashOption: {
        option: 'Encourage',
        helpText: 'Checkbox is visible and selected by default.',
        __typename: 'SquashOption',
      },
      __typename: 'BranchRuleSquashOptionUpdatePayload',
    },
  },
};

export const branchProtectionsMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/6',
      __typename: 'Project',
      group: {
        id: 'gid://gitlab/Group/1',
        __typename: 'Group',
      },
      branchRules: {
        __typename: 'BranchRuleConnection',
        nodes: [
          {
            __typename: 'BranchRule',
            name: 'main',
            isDefault: true,
            id: 'gid://gitlab/Projects/BranchRule/1',
            matchingBranchesCount,
            branchProtection: {
              __typename: 'BranchProtection',
              allowForcePush: true,
              codeOwnerApprovalRequired: true,
              mergeAccessLevels: {
                __typename: 'MergeAccessLevelConnection',
                edges: mergeAccessLevelEdges,
              },
              pushAccessLevels: {
                __typename: 'PushAccessLevelConnection',
                edges: pushAccessLevelEdges,
              },
            },
            approvalRules: {
              __typename: 'ApprovalProjectRuleConnection',
              nodes: approvalRulesMock,
            },
            externalStatusChecks: {
              __typename: 'ExternalStatusCheckConnection',
              nodes: statusChecksRulesMock,
            },
          },
          {
            __typename: 'BranchRule',
            name: '*',
            id: 'gid://gitlab/Projects/BranchRule/2',
            isDefault: false,
            matchingBranchesCount,
            branchProtection: {
              __typename: 'BranchProtection',
              allowForcePush: true,
              codeOwnerApprovalRequired: true,
              mergeAccessLevels: {
                __typename: 'MergeAccessLevelConnection',
                edges: [],
              },
              pushAccessLevels: {
                __typename: 'PushAccessLevelConnection',
                edges: [],
              },
            },
            approvalRules: {
              __typename: 'ApprovalProjectRuleConnection',
              nodes: [],
            },
            externalStatusChecks: {
              __typename: 'ExternalStatusCheckConnection',
              nodes: [],
            },
          },
        ],
      },
    },
  },
};

export const branchProtectionsNoPushAccessMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      __typename: 'Project',
      branchRules: {
        __typename: 'BranchRuleConnection',
        nodes: [
          {
            __typename: 'BranchRule',
            name: '*-test',
            isDefault: false,
            id: 'gid://gitlab/Projects/BranchRule/2',
            matchingBranchesCount,
            branchProtection: {
              __typename: 'BranchProtection',
              allowForcePush: false,
              mergeAccessLevels: {
                __typename: 'MergeAccessLevelConnection',
                edges: mergeAccessLevelEdges,
              },
              pushAccessLevels: {
                __typename: 'PushAccessLevelConnection',
                edges: [],
              },
              approvalRules: {
                __typename: 'ApprovalProjectRuleConnection',
                nodes: [],
              },
              externalStatusChecks: {
                __typename: 'ExternalStatusCheckConnection',
                nodes: [],
              },
            },
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
      group: {
        id: 'gid://gitlab/Group/1',
        __typename: 'Group',
      },
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
              __typename: 'ApprovalProjectRuleConnection',
              nodes: approvalRulesMock,
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
              __typename: 'ApprovalProjectRuleConnection',
              nodes: approvalRulesMock,
            },
            __typename: 'BranchRule',
          },
        ],
      },
    },
  },
};

// Mocks for branchRuleDelete mutation

export const deleteBranchRuleMockResponse = {
  data: {
    branchRuleDelete: {
      errors: [],
      __typename: 'BranchRuleDeletePayload',
    },
  },
};

// Mocks for editBrachRule mutation

export const mergeAccessLevelsEditResponse = {
  nodes: [
    {
      accessLevel: 40,
      accessLevelDescription: 'Administrator',
      user: {
        id: 'gid://gitlab/User/1',
        __typename: 'AccessLevelUser',
      },
      group: null,
      __typename: 'MergeAccessLevel',
    },
    {
      accessLevel: 40,
      accessLevelDescription: 'Carlos Orn',
      user: {
        id: 'gid://gitlab/User/3',
        __typename: 'AccessLevelUser',
      },
      group: null,
      __typename: 'MergeAccessLevel',
    },
  ],
  __typename: 'MergeAccessLevelConnection',
};

export const editBranchRuleMockResponse = {
  data: {
    branchRuleUpdate: {
      errors: [],
      __typename: 'BranchRuleEditPayload',
      branchRule: {
        __typename: 'BranchRule',
        name: 'newname',
        isDefault: true,
        id: 'gid://gitlab/Projects/BranchRule/1',
        matchingBranchesCount,
        branchProtection: {
          __typename: 'BranchProtection',
          allowForcePush: true,
          codeOwnerApprovalRequired: true,
          mergeAccessLevels: mergeAccessLevelsEditResponse,
          pushAccessLevels: {
            __typename: 'PushAccessLevelConnection',
            nodes: [],
          },
        },
      },
    },
  },
};

export const editRuleData = [
  { userId: 'gid://gitlab/User/123' },
  { accessLevel: 60 },
  { accessLevel: 40 },
  { accessLevel: 30 },
];

export const editRuleDataNoAccessLevels = [{ userId: 'gid://gitlab/User/123' }];

export const editRuleDataNoOne = [{ userId: 'gid://gitlab/User/123' }, { accessLevel: 0 }];

// Mocks for getBranches query

export const protectableBranchesMockResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      protectableBranches: ['make-release-umd-bundle', 'main', 'v2.x'],
      __typename: 'Project',
    },
  },
};

// Mocks for createStatusCheck mutation

export const statusCheckCreateSuccessResponse = {
  data: {
    branchRuleExternalStatusCheckCreate: {
      externalStatusCheck: statusChecksRulesMock[0],
      errors: [],
    },
  },
};

export const statusCheckUpdateSuccessResponse = {
  data: {
    branchRuleExternalStatusCheckUpdate: {
      externalStatusCheck: statusChecksRulesMock[0],
      errors: [],
    },
  },
};

export const statusCheckDeleteSuccessResponse = {
  data: {
    branchRuleExternalStatusCheckDestroy: {
      errors: [],
    },
  },
};

export const statusCheckCreateNameTakenResponse = {
  data: {
    branchRuleExternalStatusCheckCreate: {
      externalStatusCheck: null,
      errors: ['Name has already been taken'],
    },
  },
};

// Mocks for drawer component
export const allowedToMergeDrawerProps = {
  groups: [],
  isLoading: false,
  isOpen: false,
  title: 'Edit allowed to merge',
  roles: accessLevelsMock,
  users: [mergeAccessLevelEdges[0].node.user],
};

export const allowedToPushDrawerProps = {
  groups: [],
  isLoading: false,
  isOpen: false,
  title: 'Edit allowed to merge',
  roles: accessLevelsMock,
  users: [pushAccessLevelEdges[0].node.user],
  deployKeys: deployKeysMock,
};
