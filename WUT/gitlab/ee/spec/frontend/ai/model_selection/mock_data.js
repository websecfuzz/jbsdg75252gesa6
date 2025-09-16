export const mockCodeSuggestionsFeatureSettings = [
  {
    feature: 'code_completions',
    title: 'Code Completion',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: 'claude_sonnet_3_7_20250219',
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
  {
    feature: 'code_generations',
    title: 'Code Generation',
    mainFeature: 'Code Suggestions',
    selectedModel: {
      ref: '',
      name: 'GitLab Default',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockDuoChatFeatureSettings = [
  {
    feature: 'duo_chat',
    title: 'General Chat',
    mainFeature: 'GitLab Duo Chat',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockMergeRequestFeatureSettings = [
  {
    feature: 'summarize_review',
    title: 'Code Review Summary',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
  {
    feature: 'generate_commit_message',
    title: 'Merge Commit Message Generation',
    mainFeature: 'GitLab Duo for merge requests',
    selectedModel: null,
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockIssueFeatureSettings = [
  {
    feature: 'duo_chat_summarize_comments',
    title: 'Discussion Summary',
    mainFeature: 'GitLab Duo for issues',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockOtherDuoFeaturesSettings = [
  {
    feature: 'glab_ask_git_command',
    title: 'GitLab Duo for CLI',
    mainFeature: 'Other GitLab Duo features',
    selectedModel: {
      ref: 'claude_3_5_sonnet_20240620',
      name: 'Claude Sonnet 3.5 - Anthropic',
    },
    defaultModel: {
      name: 'Claude Sonnet 3.7 - Anthropic',
    },
    selectableModels: [
      {
        ref: 'claude_sonnet_3_7_20250219',
        name: 'Claude Sonnet 3.7 - Anthropic',
      },
      {
        ref: 'claude_3_5_sonnet_20240620',
        name: 'Claude Sonnet 3.5 - Anthropic',
      },
      {
        ref: 'claude_3_haiku_20240307"',
        name: 'Claude Haiku 3 - Anthropic',
      },
    ],
  },
];

export const mockAiFeatureSettings = [
  ...mockCodeSuggestionsFeatureSettings,
  ...mockDuoChatFeatureSettings,
  ...mockMergeRequestFeatureSettings,
  ...mockIssueFeatureSettings,
  ...mockOtherDuoFeaturesSettings,
];
