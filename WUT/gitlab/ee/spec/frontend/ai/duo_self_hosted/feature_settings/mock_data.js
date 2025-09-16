export const mockSelfHostedModels = [
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/1',
    name: 'Model 1',
    model: 'mistral',
    modelDisplayName: 'Mistral',
    releaseState: 'GA',
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/2',
    name: 'Model 2',
    model: 'codellama',
    modelDisplayName: 'Code Llama',
    releaseState: 'BETA',
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/3',
    name: 'Model 3',
    model: 'codegemma',
    modelDisplayName: 'CodeGemma',
    releaseState: 'BETA',
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/4',
    name: 'Model 4',
    model: 'gpt',
    modelDisplayName: 'GPT',
    releaseState: 'GA',
  },
  {
    id: 'gid://gitlab/Ai::SelfHostedModel/5',
    name: 'Model 5',
    model: 'claude_3',
    modelDisplayName: 'Claude 3',
    releaseState: 'GA',
  },
];

export const mockCodeSuggestionsFeatureSettings = [
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    releaseState: 'GA',
    provider: 'vendored',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    releaseState: 'GA',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
];

export const mockDuoChatFeatureSettings = [
  {
    feature: 'duo_chat_troubleshoot_job',
    title: 'Troubleshoot Job',
    mainFeature: 'GitLab Duo Chat',
    releaseState: 'EXPERIMENT',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 'gid://gitlab/Ai::SelfHostedModel/1',
      releaseState: 'GA',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'duo_chat',
    title: 'General Chat',
    mainFeature: 'GitLab Duo Chat',
    releaseState: 'GA',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 'gid://gitlab/Ai::SelfHostedModel/1',
      releaseState: 'GA',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'duo_chat_explain_code',
    title: 'Explain Code',
    mainFeature: 'GitLab Duo Chat',
    releaseState: 'BETA',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 'gid://gitlab/Ai::SelfHostedModel/1',
      releaseState: 'GA',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
];

export const mockMergeRequestFeatureSettings = [
  {
    feature: 'summarize_review',
    title: 'Code Review Summary',
    mainFeature: 'GitLab Duo for merge requests',
    releaseState: 'BETA',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
  {
    feature: 'generate_commit_message',
    title: 'Merge Commit Message Generation',
    mainFeature: 'GitLab Duo for merge requests',
    releaseState: 'BETA',
    provider: 'self_hosted',
    selfHostedModel: {
      id: 'gid://gitlab/Ai::SelfHostedModel/1',
      releaseState: 'GA',
    },
    validModels: { nodes: mockSelfHostedModels },
  },
];

export const mockIssueFeatureSettings = [
  {
    feature: 'duo_chat_summarize_comments',
    title: 'Discussion Summary',
    mainFeature: 'GitLab Duo for issues',
    releaseState: 'BETA',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
];

export const mockOtherDuoFeaturesSettings = [
  {
    feature: 'glab_ask_git_command',
    title: 'GitLab Duo for CLI',
    mainFeature: 'Other GitLab Duo features',
    releaseState: 'BETA',
    provider: 'disabled',
    selfHostedModel: null,
    validModels: { nodes: mockSelfHostedModels },
  },
];

export const mockAiFeatureSettings = [
  ...mockCodeSuggestionsFeatureSettings,
  ...mockDuoChatFeatureSettings,
  ...mockMergeRequestFeatureSettings,
  ...mockIssueFeatureSettings,
  ...mockOtherDuoFeaturesSettings,
];
