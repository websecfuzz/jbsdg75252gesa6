import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import RuleView from 'ee/projects/settings/branch_rules/components/view/index.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/view/status_checks/status_checks.vue';
import branchRulesQuery from 'ee/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import squashOptionQuery from '~/projects/settings/branch_rules/queries/squash_option.query.graphql';
import * as urlUtility from '~/lib/utils/url_utility';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import ProtectionToggle from '~/projects/settings/branch_rules/components/view/protection_toggle.vue';
import Protection from '~/projects/settings/branch_rules/components/view/protection.vue';
import deleteBranchRuleMutation from '~/projects/settings/branch_rules/mutations/branch_rule_delete.mutation.graphql';
import editBranchRuleMutation from 'ee_else_ce/projects/settings/branch_rules/mutations/edit_branch_rule.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  deleteBranchRuleMockResponse,
  branchProtectionsMockResponse,
  squashOptionMockResponse,
  statusChecksRulesMock,
  protectionPropsMock,
  editBranchRuleMockResponse,
  predefinedBranchRulesMockResponse,
} from './mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  getParameterByName: jest.fn().mockReturnValue('main'),
  mergeUrlParams: jest.fn().mockReturnValue('/branches?state=all&search=main'),
  joinPaths: jest.fn(),
  setUrlFragment: jest.fn(),
}));

Vue.use(VueApollo);
Vue.use(Vuex);

describe('View branch rules in enterprise edition', () => {
  let wrapper;
  let fakeApollo;
  let store;
  let axiosMock;
  const projectPath = 'test/testing';
  const protectedBranchesPath = 'protected/branches';
  const approvalRulesPath = 'approval/rules';
  const statusChecksPath = 'status/checks';
  const branchProtectionsMockRequestHandler = (response = branchProtectionsMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const squashOptionMockRequestHandler = (response = squashOptionMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const deleteBranchRuleMockRequestHandler = (response = deleteBranchRuleMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const editBranchRuleSuccessHandler = (response = editBranchRuleMockResponse) =>
    jest.fn().mockResolvedValue(response);
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = async (
    glFeatures = { editBranchRules: true },
    { showApprovers, showStatusChecks, showCodeOwners } = {},
    mockResponse,
    mutationMockResponse,
    editMutationMockResponse,
    // eslint-disable-next-line max-params
  ) => {
    axiosMock = new MockAdapter(axios);
    store = createStoreOptions({ approvals: projectSettingsModule() });
    jest.spyOn(store.modules.approvals.actions, 'setRulesFilter');
    jest.spyOn(store.modules.approvals.actions, 'fetchRules');

    fakeApollo = createMockApollo([
      [branchRulesQuery, branchProtectionsMockRequestHandler(mockResponse)],
      [squashOptionQuery, squashOptionMockRequestHandler(mutationMockResponse)],
      [deleteBranchRuleMutation, deleteBranchRuleMockRequestHandler(mutationMockResponse)],
      [editBranchRuleMutation, editBranchRuleSuccessHandler(editMutationMockResponse)],
    ]);

    wrapper = shallowMountExtended(RuleView, {
      store: new Vuex.Store(store),
      apolloProvider: fakeApollo,
      provide: {
        projectPath,
        protectedBranchesPath,
        approvalRulesPath,
        statusChecksPath,
        showApprovers,
        showStatusChecks,
        showCodeOwners,
        glFeatures,
      },
      stubs: {
        CrudComponent,
        ProtectionToggle,
        StatusChecks,
        Protection,
      },
    });

    await waitForPromises();
  };

  beforeEach(() => createComponent());

  afterEach(() => axiosMock.restore());

  const findAllowedToMerge = () => wrapper.findByTestId('allowed-to-merge-content');
  const findAllowedToPush = () => wrapper.findByTestId('allowed-to-push-content');
  const findStatusChecks = () => wrapper.findByTestId('status-checks-content');
  const findApprovalsApp = () => wrapper.findComponent(ApprovalRulesApp);
  const findProjectRules = () => wrapper.findComponent(ProjectRules);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findStatusChecksCrud = () => wrapper.findByTestId('status-checks');
  const findStatusChecksTitle = () => wrapper.findByTestId('crud-title');
  const findCodeOwnersToggle = () => wrapper.findByTestId('code-owners-content');
  const findStatusChecksDrawer = () => wrapper.findByTestId('status-checks-drawer');
  const findSquashSettingContent = () => wrapper.findByTestId('squash-setting-content');

  describe('Squash settings', () => {
    it('renders squash option and help text when available', () => {
      const content = findSquashSettingContent();
      expect(content.text()).toContain('Encourage');
      expect(content.text()).toContain('Checkbox is visible and selected by default.');
    });
  });

  it('renders a branch protection component for push rules', () => {
    expect(findAllowedToPush().props()).toMatchObject({
      roles: protectionPropsMock.roles,
      header: 'Allowed to push and merge',
      count: 2,
    });
  });

  it('renders a branch protection component for merge rules', () => {
    expect(findAllowedToMerge().props()).toMatchObject({
      roles: protectionPropsMock.roles,
      header: 'Allowed to merge',
      count: 2,
    });
  });

  describe('Code owner approvals', () => {
    it('does not render a code owner approval section by default', () => {
      expect(findCodeOwnersToggle().exists()).toBe(false);
    });

    it.each`
      codeOwnerApprovalRequired | iconTitle                                       | description
      ${true}                   | ${'Requires code owner approval'}               | ${'Changed files listed in %{linkStart}CODEOWNERS%{linkEnd} require an approval for merge requests and will be rejected for code pushes.'}
      ${false}                  | ${'Does not require approval from code owners'} | ${'Changed files listed in %{linkStart}CODEOWNERS%{linkEnd} require an approval for merge requests and will be rejected for code pushes.'}
    `(
      'renders code owners approval section with the correct iconTitle and description',
      async ({ codeOwnerApprovalRequired, iconTitle, description }) => {
        const mockResponse = branchProtectionsMockResponse;
        mockResponse.data.project.branchRules.nodes[0].branchProtection.codeOwnerApprovalRequired =
          codeOwnerApprovalRequired;
        await createComponent({ editBranchRules: true }, { showCodeOwners: true }, mockResponse);

        expect(findCodeOwnersToggle().props('iconTitle')).toEqual(iconTitle);
        expect(findCodeOwnersToggle().props('description')).toEqual(description);
      },
    );

    it('emits a tracking event, when Code Owner Approval toggle is switched', async () => {
      await createComponent({ editBranchRules: true }, { showCodeOwners: true });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findCodeOwnersToggle().vm.$emit('toggle', false);
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith('change_require_codeowner_approval', {
        label: 'branch_rule_details',
      });
    });
  });

  it('does not render approvals and status checks sections by default', () => {
    expect(findApprovalsApp().exists()).toBe(false);
    expect(findStatusChecksCrud().exists()).toBe(false);
  });

  describe('if "showApprovers" is true', () => {
    beforeEach(() => createComponent({}, { showApprovers: true }));

    it('sets an approval rules filter', () => {
      expect(store.modules.approvals.actions.setRulesFilter).toHaveBeenCalledWith(
        expect.anything(),
        ['test'],
      );
    });

    it('fetches the approval rules', () => {
      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledTimes(1);
    });

    it('re-fetches the approval rules when a rule is successfully added/edited', async () => {
      findApprovalsApp().vm.$emit('submitted');
      await waitForPromises();

      expect(store.modules.approvals.actions.setRulesFilter).toHaveBeenCalledTimes(2);
      expect(store.modules.approvals.actions.fetchRules).toHaveBeenCalledTimes(2);
    });

    it('renders the approval rules component with correct props', () => {
      expect(findApprovalsApp().props('isMrEdit')).toBe(false);
    });

    it('renders the project rules component', () => {
      expect(findProjectRules().exists()).toBe(true);
    });
  });

  describe('if "showStatusChecks" is true', () => {
    it('does not render status check section for all protected branches', () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('All protected branches');
      createComponent({ editBranchRules: true }, { showStatusChecks: true });
      expect(findStatusChecksTitle().exists()).toBe(false);
      expect(findStatusChecksDrawer().exists()).toBe(false);
    });

    it('renders status check section for all branches', async () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('All branches');
      createComponent(
        { editBranchRules: true },
        { showStatusChecks: true },
        predefinedBranchRulesMockResponse,
      );
      await waitForPromises();
      expect(findCrudComponent().props('title')).toBe('Rule target');
      expect(findStatusChecksDrawer().exists()).toBe(true);
    });

    it('renders status check section for non-predefined branch', async () => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('main');
      createComponent(
        { editBranchRules: true },
        { showStatusChecks: true },
        branchProtectionsMockResponse,
      );
      await waitForPromises();
      expect(findCrudComponent().props('title')).toBe('Rule target');
      expect(findStatusChecksDrawer().exists()).toBe(true);
    });
  });

  describe('When edit_branch_rules feature flag is disabled', () => {
    beforeEach(() => {
      jest.spyOn(urlUtility, 'getParameterByName').mockReturnValue('main');
    });
    it.each`
      codeOwnerApprovalRequired | title                                           | description
      ${true}                   | ${'Requires code owner approval'}               | ${'Also rejects code pushes that change files listed in CODEOWNERS file.'}
      ${false}                  | ${'Does not require approval from code owners'} | ${'Also accepts code pushes that change files listed in CODEOWNERS file.'}
    `(
      'renders code owners approval section with the correct title and description',
      async ({ codeOwnerApprovalRequired, title, description }) => {
        const mockResponse = branchProtectionsMockResponse;
        mockResponse.data.project.branchRules.nodes[0].branchProtection.codeOwnerApprovalRequired =
          codeOwnerApprovalRequired;
        await createComponent({ editBranchRules: false }, { showCodeOwners: true }, mockResponse);
        expect(findCodeOwnersToggle().props('iconTitle')).toEqual(title);
        expect(findCodeOwnersToggle().props('description')).toEqual(description);
      },
    );

    it('renders a branch protection component for status checks if "showStatusChecks" is true', async () => {
      await createComponent({ editBranchRules: false }, { showStatusChecks: true });

      expect(findCrudComponent().props('title')).toBe('Rule target');
      expect(findStatusChecks().props()).toMatchObject({
        header: 'Status checks',
        count: 2,
        headerLinkHref: statusChecksPath,
        headerLinkTitle: 'Manage in status checks',
        statusChecks: statusChecksRulesMock,
      });
    });
  });
});
