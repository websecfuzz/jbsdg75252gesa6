export const agentVulnerabilityImages = {
  data: {
    project: {
      id: 'gid://gitlab/Project/5000207',
      clusterAgent: {
        id: 'gid://gitlab/Clusters::Agent/1',
        vulnerabilityImages: {
          nodes: [
            {
              name: 'long-image-name',
              __typename: 'VulnerabilityContainerImage',
            },
          ],
          __typename: 'VulnerabilityContainerImageConnection',
        },

        __typename: 'ClusterAgent',
      },
      __typename: 'Project',
    },
  },
};

export const projectVulnerabilityImages = {
  data: {
    project: {
      id: 'gid://gitlab/Project/5000207',
      vulnerabilityImages: {
        nodes: [
          {
            name: 'long-image-name',
            __typename: 'VulnerabilityContainerImage',
          },
          {
            name: 'second-long-image-name',
            __typename: 'VulnerabilityContainerImage',
          },
          { name: 'third-image', __typename: 'VulnerabilityContainerImage' },
        ],
        __typename: 'VulnerabilityContainerImageConnection',
      },
      __typename: 'Project',
    },
  },
};

export const projectClusters = {
  data: {
    project: {
      id: 'gid://gitlab/Project/5000207',
      clusterAgents: {
        nodes: [
          {
            id: 'gid://gitlab/Clusters::Agent/2',
            name: 'primary-agent',
            __typename: 'ClusterAgentConnection',
          },
          {
            id: 'gid://gitlab/Clusters::Agent/007',
            name: 'james-bond-agent',
            __typename: 'ClusterAgentConnection',
          },
          {
            id: 'gid://gitlab/Clusters::Agent/3',
            name: 'jason-bourne-agent',
            __typename: 'ClusterAgentConnection',
          },
        ],
        __typename: 'ClusterAgentConnection',
      },
      __typename: 'Project',
    },
  },
};

export const clusterImageScanningVulnerability = {
  mergeRequest: null,
  __typename: 'Vulnerability',
  id: 'gid://gitlab/Vulnerability/22087293',
  title: 'CVE-2021-29921',
  state: 'DETECTED',
  severity: 'CRITICAL',
  detectedAt: '2021-11-04T20:01:14Z',
  vulnerabilityPath:
    '/gitlab-org/protect/demos/agent-cluster-image-scanning-demo/-/security/vulnerabilities/22087293',
  resolvedOnDefaultBranch: false,
  userNotesCount: 0,
  aiResolutionAvailable: false,
  aiResolutionEnabled: false,
  falsePositive: false,
  issueLinks: {
    nodes: [],
    __typename: 'VulnerabilityIssueLinkConnection',
  },
  identifiers: [
    {
      externalType: 'cve',
      name: 'CVE-2021-29921',
      __typename: 'VulnerabilityIdentifier',
    },
  ],
  location: {
    __typename: 'VulnerabilityLocationClusterImageScanning',
    kubernetesResource: {
      agent: {
        name: 'cis-demo',
        webPath:
          '/gitlab-org/protect/demos/agent-cluster-image-scanning-demo/-/cluster_agents/cis-demo',
        __typename: 'ClusterAgent',
      },
      __typename: 'VulnerableKubernetesResource',
    },
  },
};

export const containerScanningForRegistryVulnerability = {
  id: 'id_0',
  detectedAt: '2020-07-29T15:36:54Z',
  mergeRequest: {
    id: 'mr-1',
    webUrl: 'www.testmr.com/1',
    state: 'status_warning',
    iid: 1,
  },
  identifiers: [
    {
      externalType: 'cve',
      name: 'CVE-2018-1234',
    },
    {
      externalType: 'gemnasium',
      name: 'Gemnasium-2018-1234',
    },
  ],
  dismissalReason: 'USED_IN_TESTS',
  title: 'Vulnerability 0',
  severity: 'critical',
  state: 'DISMISSED',
  reportType: 'SAST',
  resolvedOnDefaultBranch: false,
  location: {
    image:
      'registry.gitlab.com/groulot/container-scanning-test/main:5f21de6956aee99ddb68ae49498662d9872f50ff',
    containerRepositoryUrl: 'http://www.gitlab.com',
  },
  project: {
    id: 'project-1',
    nameWithNamespace: 'Administrator / Security reports',
  },
  scanner: {
    id: 'scanner-1',
    vendor: 'GitLab',
    name: 'Gemnasium',
  },
  issueLinks: {
    nodes: [
      {
        id: 'issue-1',
        issue: {
          id: 'issue-1',
          iid: 15,
          webUrl: 'url',
          webPath: 'path',
          title: 'title',
          state: 'state',
          resolvedOnDefaultBranch: true,
        },
      },
    ],
  },
  externalIssueLinks: {
    nodes: [
      {
        id: 'issue-1',
        issue: { iid: 15, externalTracker: 'jira', resolvedOnDefaultBranch: true },
      },
    ],
  },
  vulnerabilityPath: 'path',
  userNotesCount: 1,
  aiResolutionAvailable: false,
  aiResolutionEnabled: false,
  hasRemediations: true,
  __typename: 'Vulnerability',
};

export const generateVulnerabilities = () => [
  {
    id: 'id_0',
    detectedAt: '2020-07-29T15:36:54Z',
    mergeRequest: {
      id: 'mr-1',
      webUrl: 'www.testmr.com/1',
      state: 'status_warning',
      iid: 1,
    },
    identifiers: [
      {
        externalType: 'cve',
        name: 'CVE-2018-1234',
      },
      {
        externalType: 'gemnasium',
        name: 'Gemnasium-2018-1234',
      },
    ],
    cvss: [{ version: '3.1', overallScore: 9.8 }],
    cveEnrichment: { isKnownExploit: false, epssScore: 0.85 },
    dismissalReason: 'USED_IN_TESTS',
    title: 'Vulnerability 0',
    severity: 'critical',
    state: 'DISMISSED',
    reportType: 'SAST',
    resolvedOnDefaultBranch: false,
    location: {
      image:
        'registry.gitlab.com/groulot/container-scanning-test/main:5f21de6956aee99ddb68ae49498662d9872f50ff',
    },
    project: {
      id: 'project-1',
      nameWithNamespace: 'Administrator / Security reports',
    },
    scanner: {
      id: 'scanner-1',
      vendor: 'GitLab',
      name: 'Gemnasium',
    },
    issueLinks: {
      nodes: [
        {
          id: 'issue-1',
          issue: {
            id: 'issue-1',
            iid: 15,
            webUrl: 'url',
            webPath: 'path',
            title: 'title',
            state: 'state',
            resolvedOnDefaultBranch: true,
          },
        },
      ],
    },
    externalIssueLinks: {
      nodes: [
        {
          id: 'issue-1',
          issue: { iid: 15, externalTracker: 'jira', resolvedOnDefaultBranch: true },
        },
      ],
    },
    vulnerabilityPath: 'path',
    userNotesCount: 1,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: true,
      expectedToBeArchivedOn: '2025-03-01',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_1',
    detectedAt: '2020-07-22T19:31:24Z',
    resolvedOnDefaultBranch: false,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [
      {
        externalType: 'gemnasium',
        name: 'Gemnasium-2018-1234',
      },
    ],
    cvss: [],
    cveEnrichment: null,
    dismissalReason: null,
    title: 'Vulnerability 1',
    severity: 'high',
    state: 'DETECTED',
    reportType: 'DEPENDENCY_SCANNING',
    location: {
      file: 'src/main/java/com/gitlab/security_products/tests/App.java',
      startLine: '1337',
      blobPath:
        '/gitlab-org/security-reports2/-/blob/e5c61e4d5d0b8418011171def04ca0aa36532621/src/main/java/com/gitlab/security_products/tests/App.java',
    },
    project: {
      id: 'project-2',
      nameWithNamespace: 'Administrator / Vulnerability reports',
    },
    scanner: { id: 'scanner-2', vendor: 'GitLab', name: 'GitLeaks' },
    vulnerabilityPath: '#',
    userNotesCount: 0,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-01',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_2',
    detectedAt: '2020-08-22T20:00:12Z',
    resolvedOnDefaultBranch: false,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [],
    dismissalReason: null,
    cvss: [],
    cveEnrichment: null,
    title: 'Vulnerability 2',
    severity: 'high',
    state: 'DETECTED',
    reportType: 'CUSTOM_SCANNER_WITHOUT_TRANSLATION',
    location: {
      file: 'src/main/java/com/gitlab/security_products/tests/App.java',
    },
    project: {
      id: 'project-3',
      nameWithNamespace: 'Mixed Vulnerabilities / Dependency List Test 01',
    },
    scanner: {
      id: 'scanner-3',
      vendor: 'My Custom Scanner',
      name: 'GitLeaks',
    },
    vulnerabilityPath: 'path',
    userNotesCount: 2,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-04',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_3',
    title: 'Vulnerability 3',
    detectedAt: new Date(),
    resolvedOnDefaultBranch: true,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [],
    dismissalReason: null,
    cvss: [],
    cveEnrichment: null,
    reportType: '',
    severity: 'high',
    state: 'DETECTED',
    location: {
      file: 'yarn.lock',
    },
    project: {
      id: 'project-4',
      nameWithNamespace: 'Mixed Vulnerabilities / Rails App',
    },
    scanner: { id: 'scanner-3', vendor: '', name: 'GitLeaks' },
    vulnerabilityPath: 'path',
    userNotesCount: 3,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-07',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_4',
    title: 'Vulnerability 4',
    severity: 'critical',
    state: 'DISMISSED',
    detectedAt: new Date(),
    resolvedOnDefaultBranch: true,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [],
    dismissalReason: null,
    cvss: [],
    cveEnrichment: null,
    reportType: 'DAST',
    location: {},
    project: {
      id: 'project-5',
      nameWithNamespace: 'Administrator / Security reports',
    },
    scanner: { id: 'scanner-4', vendor: 'GitLab', name: 'GitLeaks' },
    vulnerabilityPath: 'path',
    userNotesCount: 4,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-10',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_5',
    title: 'Vulnerability 5',
    severity: 'high',
    state: 'DETECTED',
    detectedAt: new Date(),
    resolvedOnDefaultBranch: false,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [],
    dismissalReason: null,
    cvss: [],
    cveEnrichment: null,
    reportType: 'DEPENDENCY_SCANNING',
    location: {
      path: '/v1/trees',
    },
    project: {
      id: 'project-6',
      nameWithNamespace: 'Administrator / Security reports',
    },
    scanner: { id: 'scanner-5', vendor: 'GitLab', name: 'GitLeaks' },
    vulnerabilityPath: 'path',
    userNotesCount: 5,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-20',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
  {
    id: 'id_6',
    title: 'Vulnerability 6',
    severity: 'high',
    state: 'DETECTED',
    detectedAt: new Date(),
    resolvedOnDefaultBranch: false,
    issueLinks: [],
    mergeRequest: null,
    identifiers: [],
    dismissalReason: null,
    cvss: [],
    cveEnrichment: null,
    reportType: 'DEPENDENCY_SCANNING',
    location: {
      path: '/v1/trees',
      file: 'yarn.lock',
    },
    project: {
      id: 'project-6',
      nameWithNamespace: 'Administrator / Security reports',
    },
    scanner: { id: 'scanner-5', vendor: 'GitLab', name: 'GitLeaks' },
    vulnerabilityPath: 'path',
    userNotesCount: 5,
    aiResolutionAvailable: false,
    aiResolutionEnabled: false,
    hasRemediations: true,
    archivalInformation: {
      aboutToBeArchived: false,
      expectedToBeArchivedOn: '2026-03-30',
    },
    reachability: 'UNKNOWN',
    __typename: 'Vulnerability',
  },
];

export const vulnerabilities = generateVulnerabilities();

export const generateFindings = () => [
  {
    id: 'id_0',
    name: 'Finding 0',
    description: 'Description 0',
    falsePositive: false,
    identifiers: [
      {
        externalType: 'cve',
        name: 'CVE-2018-1234',
      },
      {
        externalType: 'gemnasium',
        name: 'Gemnasium-2018-1234',
      },
    ],
    reportType: 'SAST',
    scanner: {
      id: 'scanner-1',
      vendor: 'GitLab',
      name: 'GitLeaks',
    },
    state: 'DETECTED',
    dismissalReason: null,
    severity: 'CRITICAL',
    solution: 'Upgrade to version 1.2.0 or above.',
    location: {
      image:
        'registry.gitlab.com/groulot/container-scanning-test/main:5f21de6956aee99ddb68ae49498662d9872f50ff',
    },
    issueLinks: {
      nodes: [
        {
          id: 'issue-1',
          issue: {
            id: 'issue-1',
            iid: 15,
            webUrl: 'url',
            webPath: 'path',
            title: 'title',
            state: 'state',
            resolvedOnDefaultBranch: true,
          },
        },
      ],
    },
    vulnerability: {
      id: 'gid://gitlab/Vulnerability/1',
      externalIssueLinks: {
        nodes: [
          {
            id: 'issue-1',
            issue: {
              webUrl: 'https://test.atlassian.net/browse/TP-1',
              externalTracker: 'jira',
              title: 'Vulnerability 0 issue',
              iid: 'TP-1',
            },
          },
        ],
      },
    },
  },
];

export const findings = generateFindings();
