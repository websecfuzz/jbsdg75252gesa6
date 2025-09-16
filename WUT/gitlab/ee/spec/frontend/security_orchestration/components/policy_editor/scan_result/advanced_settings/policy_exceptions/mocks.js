export const mockBranchPatterns = [
  { id: 'pattern_1', source: 'main-*', target: 'target-1' },
  { id: 'pattern_2', source: 'feature-.*', target: 'target-2' },
];

export const mockTokens = [
  { id: 1, name: 'project-token-1', full_name: 'project-token-1-full-name' },
  { id: 2, name: 'project-token-2', full_name: 'project-token-2-full-name' },
  { id: 3, name: 'project-token-3', full_name: 'project-token-3-full-name' },
  { id: 4, name: 'project-token-4', full_name: 'project-token-4-full-name' },
];

export const mockAccounts = [
  { name: 'project-account-1', username: 'project-account-1-username' },
  { name: 'project-account-2', username: 'project-account-2-username' },
  { name: 'project-account-3', username: 'project-account-3-username' },
];

export const mockServiceAccounts = [
  { id: 1, name: 'service-account-1', username: 'sa1' },
  { id: 2, name: 'service-account-2', username: 'sa2' },
  { id: 3, name: 'service-account-3', username: 'sa3' },
];

export const mockSelectedAccounts = [
  { id: '1', account: { username: 'project-account-1-username' } },
  { id: '2', account: { username: 'project-account-2-username' } },
];
