export const listItems = [
  { value: 'CLAUDE_3', text: 'Claude 3', releaseState: 'GA' },
  { value: 'CODELLAMA', text: 'Code Llama', releaseState: 'BETA' },
  { value: 'CODEGEMMA', text: 'CodeGemma', releaseState: 'BETA' },
  { value: 'DEEPSEEKCODER', text: 'DeepSeek Coder', releaseState: 'BETA' },
  { value: 'GPT', text: 'GPT', releaseState: 'GA' },
];

export const featureSettingsListItems = [
  { value: 'gid://gitlab/Ai::SelfHostedModel/1', text: 'Claude 3 deployment', releaseState: 'GA' },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/2',
    text: 'Code Llama deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/3',
    text: 'CodeGemma deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/4',
    text: 'DeepSeek Coder deployment',
    releaseState: 'BETA',
  },
  {
    value: 'gid://gitlab/Ai::SelfHostedModel/5',
    text: 'GPT deployment',
    releaseState: 'GA',
  },
  { value: 'disabled', text: 'Disable' },
  { value: 'vendored', text: 'GitLab AI Vendor' },
];
