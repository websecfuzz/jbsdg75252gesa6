import { s__ } from '~/locale';

export const ACTION_LABELS = {
  codeAdded: {
    title: s__('LearnGitLab|Add code'),
    trackLabel: 'add_code',
    section: 'code',
    position: 1,
    openInNewTab: true,
  },
  created: {
    title: s__('LearnGitLab|Create a repository'),
    actionLabel: s__('LearnGitLab|Create a repository'),
    description: s__('LearnGitLab|Create or import your first repository into your new project.'),
    trackLabel: 'create_a_repository',
    section: 'code',
    position: 0,
  },
  userAdded: {
    title: s__('LearnGitLab|Invite your colleagues'),
    actionLabel: s__('LearnGitLab|Invite your colleagues'),
    description: s__(
      'LearnGitLab|GitLab works best as a team. Invite your colleague to enjoy all features.',
    ),
    trackLabel: 'invite_your_colleagues',
    section: 'workspace',
    position: 0,
  },
  duoSeatAssigned: {
    title: s__('LearnGitLab|Assign a GitLab Duo seat to your colleagues'),
    trackLabel: 'duo_seat_assigned',
    section: 'workspace',
    position: 1,
  },
  pipelineCreated: {
    title: s__("LearnGitLab|Set up your first project's CI/CD"),
    actionLabel: s__('LearnGitLab|Set up CI/CD'),
    description: s__('LearnGitLab|Save time by automating your integration and deployment tasks.'),
    trackLabel: 'set_up_your_first_project_s_ci_cd',
    section: 'workspace',
    position: 2,
  },
  trialStarted: {
    title: s__('LearnGitLab|Start a free trial of GitLab Ultimate'),
    actionLabel: s__('LearnGitLab|Try GitLab Ultimate for free'),
    description: s__('LearnGitLab|Try all GitLab features for 60 days, no credit card required.'),
    trackLabel: 'start_a_free_trial_of_gitlab_ultimate',
    section: 'workspace',
    position: 3,
    openInNewTab: true,
  },
  codeOwnersEnabled: {
    title: s__('LearnGitLab|Add code owners'),
    actionLabel: s__('LearnGitLab|Add code owners'),
    description: s__(
      'LearnGitLab|Prevent unexpected changes to important assets by assigning ownership of files and paths.',
    ),
    trackLabel: 'add_code_owners',
    trialRequired: true,
    section: 'workspace',
    position: 4,
    openInNewTab: true,
  },
  requiredMrApprovalsEnabled: {
    title: s__('LearnGitLab|Enable require merge approvals'),
    actionLabel: s__('LearnGitLab|Enable require merge approvals'),
    description: s__('LearnGitLab|Route code reviews to the right reviewers, every time.'),
    trackLabel: 'enable_require_merge_approvals',
    trialRequired: true,
    section: 'workspace',
    position: 5,
    openInNewTab: true,
  },
  mergeRequestCreated: {
    title: s__('LearnGitLab|Submit a merge request (MR)'),
    actionLabel: s__('LearnGitLab|Submit a merge request (MR)'),
    description: s__('LearnGitLab|Review and edit proposed changes to source code.'),
    trackLabel: 'submit_a_merge_request_mr',
    section: 'plan',
    position: 1,
  },
  issueCreated: {
    title: s__('LearnGitLab|Create an issue'),
    actionLabel: s__('LearnGitLab|Create an issue'),
    description: s__(
      'LearnGitLab|Create/import issues (tickets) to collaborate on ideas and plan work.',
    ),
    trackLabel: 'create_an_issue',
    section: 'plan',
    position: 0,
  },
  licenseScanningRun: {
    title: s__('LearnGitLab|Scan dependencies for licenses'),
    trackLabel: 'scan_dependencies_for_licenses',
    trialRequired: true,
    section: 'deploy',
    position: 2,
  },
  secureDependencyScanningRun: {
    title: s__('LearnGitLab|Scan dependencies for vulnerabilities'),
    trackLabel: 'scan_dependencies_for_vulnerabilities',
    trialRequired: true,
    section: 'deploy',
    position: 3,
  },
  secureDastRun: {
    title: s__('LearnGitLab|Analyze your application for vulnerabilities with DAST'),
    trackLabel: 'analyze_your_application_for_vulnerabilities_with_dast',
    trialRequired: true,
    section: 'deploy',
    position: 4,
  },
};

export const ACTION_SECTIONS = {
  code: {
    title: s__('LearnGitLab|Set up your code'),
    description: s__(
      'LearnGitLab|Use the built-in editor, WebIDE, or upload code using your preferred method.',
    ),
  },
  workspace: {
    title: s__('LearnGitLab|Configure your project'),
    description: s__(
      "LearnGitLab|Complete these tasks first so you can enjoy GitLab's features to their fullest:",
    ),
  },
  plan: {
    title: s__('LearnGitLab|Plan and execute work together'),
    description: s__('LearnGitLab|Create a workflow, and learn how GitLab features work together:'),
  },
  deploy: {
    title: s__('LearnGitLab|Secure your deployment'),
    description: s__(
      'LearnGitLab|Use GitLab to deploy your application, monitor its health, and keep it secure:',
    ),
  },
};

export const INVITE_MODAL_OPEN_COOKIE = 'confetti_post_signup';
