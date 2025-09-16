import { TOKEN_TYPES } from 'ee/geo_replicable/constants';

export const MOCK_REPLICABLE_TYPES = [
  {
    titlePlural: 'Design Management Repositories',
    namePlural: 'design_management_repositories',
    graphqlFieldName: 'designManagementRepositoryRegistries',
    graphqlMutationRegistryClass: 'DESIGN_MANAGEMENT_REPOSITORY_REGISTRY',
  },
  {
    titlePlural: 'Project Repositories',
    namePlural: 'project_repositories',
    graphqlFieldName: 'projectRepositoryRegistries',
    graphqlMutationRegistryClass: 'PROJECT_REPOSITORY_REGISTRY',
  },
  {
    titlePlural: 'Package Files',
    namePlural: 'package_files',
    graphqlFieldName: 'packageFileRegistries',
    graphqlMutationRegistryClass: 'PACKAGE_FILE_REGISTRY',
  },
];

export const MOCK_REPLICABLE_TYPE = MOCK_REPLICABLE_TYPES[0].namePlural;

export const MOCK_GRAPHQL_REGISTRY = MOCK_REPLICABLE_TYPES[0].graphqlFieldName;

export const MOCK_GRAPHQL_REGISTRY_CLASS = MOCK_REPLICABLE_TYPES[0].graphqlMutationRegistryClass;

export const MOCK_BASIC_GRAPHQL_DATA = [
  {
    id: 'gid://gitlab/Geo::MockRegistry/1',
    modelRecordId: 1,
    state: 'PENDING',
    verificationState: 'SUCCEEDED',
    lastSyncedAt: new Date().toString(),
    verifiedAt: new Date().toString(),
    lastSyncFailure: null,
    verificationFailure: null,
  },
  {
    id: 'gid://gitlab/Geo::MockRegistry/2',
    modelRecordId: 2,
    state: 'SYNCED',
    verificationState: 'FAILED',
    lastSyncedAt: null,
    verifiedAt: null,
    lastSyncFailure: null,
    verificationFailure: null,
  },
  {
    id: 'gid://gitlab/Geo::MockRegistry/3',
    modelRecordId: 3,
    state: 'FAILED',
    verificationState: 'FAILED',
    lastSyncedAt: new Date().toString(),
    verifiedAt: new Date().toString(),
    lastSyncFailure: 'There was a sync failure',
    verificationFailure: 'There was a verification failure',
  },
];

export const MOCK_GRAPHQL_PAGINATION_DATA = {
  hasNextPage: true,
  hasPreviousPage: true,
  startCursor: 'abc123',
  endCursor: 'abc124',
};

// Query.geoNode to be renamed to Query.geoSite => https://gitlab.com/gitlab-org/gitlab/-/issues/396739
export const MOCK_BASIC_GRAPHQL_QUERY_RESPONSE = {
  geoNode: {
    [MOCK_GRAPHQL_REGISTRY]: {
      pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
      nodes: MOCK_BASIC_GRAPHQL_DATA,
    },
  },
};

export const MOCK_REPLICABLE_BASE_PATH = '/admin/geo/sites/2/replication/project_repositories';

export const MOCK_REPLICABLE_TYPE_FILTER = {
  type: TOKEN_TYPES.REPLICABLE_TYPE,
  value: 'project_repositories',
};

export const MOCK_REPLICATION_STATUS_FILTER = {
  type: TOKEN_TYPES.REPLICATION_STATUS,
  value: {
    data: 'synced',
  },
};
