import Vue, { nextTick } from 'vue';
import { GlForm, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ModalCopyButton from '~/vue_shared/components/modal_copy_button.vue';
import { HTTP_STATUS_OK, HTTP_STATUS_UNPROCESSABLE_ENTITY } from '~/lib/utils/http_status';
import WorkItemCreateBranchMergeRequestModal from '~/work_items/components/work_item_development/work_item_create_branch_merge_request_modal.vue';
import getProjectRootRef from '~/work_items/graphql/get_project_root_ref.query.graphql';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import ProjectFormGroup from '~/confidential_merge_request/components/project_form_group.vue';

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

jest.mock('~/confidential_merge_request/state', () => ({
  selectedProject: {
    pathWithNamespace: 'fullPath-fork-new',
  },
}));

describe('CreateBranchMergeRequestModal', () => {
  Vue.use(VueApollo);

  let wrapper;
  let mock;
  let mockApollo;

  const showToast = jest.fn();

  const projectRefHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: 'gid://gitlab/Project/2',
        repository: {
          rootRef: 'master',
          __typename: 'Repository',
        },
        __typename: 'Project',
      },
    },
  });

  const createWrapper = ({
    workItemIid = '1',
    showBranchFlow = true,
    showModal = true,
    workItemType = 'Issue',
    workItemFullPath = 'fullPath',
    groupPath = 'groupPath',
    projectId = 'gid://gitlab/Project/2',
    isConfidentialWorkItem = false,
  } = {}) => {
    mockApollo = createMockApollo([[getProjectRootRef, projectRefHandler]]);

    wrapper = shallowMount(WorkItemCreateBranchMergeRequestModal, {
      apolloProvider: mockApollo,
      propsData: {
        workItemIid,
        workItemType,
        showBranchFlow,
        showModal,
        workItemFullPath,
        projectId,
        isConfidentialWorkItem,
      },
      provide: {
        groupPath,
      },
      mocks: {
        $toast: {
          show: showToast,
        },
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findGlModal = () => wrapper.findComponent(GlModal);
  const firePrimaryEvent = () => findGlModal().vm.$emit('primary', { preventDefault: jest.fn() });
  const findPrimaryButton = () => findGlModal().props('actionPrimary');
  const findPrivateForksSelector = () => wrapper.findComponent(ProjectFormGroup);
  const findSourceBranch = () => wrapper.find('[data-testid="source-name"]');
  const findTargetBranch = () => wrapper.find('[data-testid="target-name"]');
  const findCopyToClipboardButton = () => wrapper.findComponent(ModalCopyButton);

  describe('when hosted at the root', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      mock.onGet('/fullPath/-/issues/1/can_create_branch').reply(HTTP_STATUS_OK, {
        can_create_branch: true,
        suggested_branch_name: 'suggested_branch_name#with_hash',
      });
      return createWrapper();
    });

    afterEach(() => {
      mock.restore();
    });

    describe('on initialise', () => {
      it('shows the form', () => {
        expect(findForm().exists()).toBe(true);
      });
    });

    describe('Branch creation', () => {
      it('calls the create branch mutation with the correct parameters', async () => {
        createWrapper();
        await waitForPromises();

        jest.spyOn(axios, 'post');
        mock
          .onPost('/fullPath/-/branches')
          .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

        firePrimaryEvent();
        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(`/fullPath/-/branches`, {
          branch_name: 'suggested_branch_name#with_hash',
          confidential_issue_project_id: null,
          format: 'json',
          issue_iid: '1',
          ref: 'master',
        });
      });

      it('calls the create branch with correct source and target branch', async () => {
        createWrapper();
        await waitForPromises();

        jest.spyOn(axios, 'post');
        mock
          .onPost('/fullPath/-/branches')
          .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

        findSourceBranch().vm.$emit('input', 'source');
        findTargetBranch().vm.$emit('input', 'target');
        firePrimaryEvent();

        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(`/fullPath/-/branches`, {
          branch_name: 'target',
          confidential_issue_project_id: null,
          format: 'json',
          issue_iid: '1',
          ref: 'source',
        });
      });

      describe('Copy to clipboard', () => {
        it('shows a button that copies the branch name to the clipboard', async () => {
          findTargetBranch().vm.$emit('input', 'target');

          await nextTick();

          expect(findCopyToClipboardButton().exists()).toBe(true);
          expect(findCopyToClipboardButton().props()).toMatchObject({
            text: `target`,
            title: 'Copy to clipboard',
          });
        });
      });

      it('shows a success toast message when branch is created', async () => {
        createWrapper();
        await waitForPromises();

        mock
          .onPost('/fullPath/-/branches')
          .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

        firePrimaryEvent();
        await waitForPromises();

        expect(showToast).toHaveBeenCalledWith('Branch created.', {
          autoHideDelay: 10000,
          action: {
            text: 'View branch',
            onClick: expect.any(Function),
          },
        });
      });

      it('shows an error alert when branch creation fails', async () => {
        mock
          .onPost('/fullPath/-/branches')
          .reply(HTTP_STATUS_UNPROCESSABLE_ENTITY, { message: 'Error creating branch' });
        createWrapper();
        await waitForPromises();

        firePrimaryEvent();
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to create a branch for this issue. Please try again.',
        });
      });
    });

    describe('Merge request creation', () => {
      it('redirects to the the create merge branch request url with the correct parameters', async () => {
        createWrapper({ showBranchFlow: false });
        await waitForPromises();

        jest.spyOn(axios, 'post');
        mock
          .onPost('/fullPath/-/branches')
          .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

        findSourceBranch().vm.$emit('input', 'source_mr');
        findTargetBranch().vm.$emit('input', 'target_mr');
        firePrimaryEvent();

        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(`/fullPath/-/branches`, {
          branch_name: 'target_mr',
          confidential_issue_project_id: null,
          format: 'json',
          issue_iid: '1',
          ref: 'source_mr',
        });

        await waitForPromises();

        await nextTick();

        expect(visitUrl).toHaveBeenCalledWith(
          '/fullPath/-/merge_requests/new?merge_request%5Bissue_iid%5D=1&merge_request%5Bsource_branch%5D=target_mr&merge_request%5Btarget_branch%5D=source_mr',
        );
      });

      describe('confidential merge request', () => {
        beforeEach(() => {
          createWrapper({ showBranchFlow: false, isConfidentialWorkItem: true });
          return waitForPromises();
        });

        it('shows the private forks selector', () => {
          expect(findPrivateForksSelector().exists()).toBe(true);
        });

        it('passes the required props to the private forks selector', () => {
          expect(findPrivateForksSelector().props()).toMatchObject({
            namespacePath: 'groupPath',
            projectPath: 'fullPath',
            helpPagePath: '/help/user/project/merge_requests/_index.md',
            newForkPath: '/fullPath/-/forks/new',
          });
        });

        it('create merge request button should be enabled when there is a private fork selected', () => {
          expect(findPrimaryButton().attributes.disabled).toEqual(false);
        });

        it('replaces the create branch and create merge request paths with forkPath with passing of work item project id', async () => {
          jest.spyOn(axios, 'post');
          mock
            .onPost('/fullPath/-/branches')
            .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

          firePrimaryEvent();
          await waitForPromises();

          expect(axios.post).toHaveBeenCalledWith(`/fullPath-fork-new/-/branches`, {
            branch_name: 'suggested_branch_name#with_hash',
            confidential_issue_project_id: 'gid://gitlab/Project/2',
            format: 'json',
            issue_iid: '1',
            ref: 'master',
          });

          await waitForPromises();

          await nextTick();

          expect(visitUrl).toHaveBeenCalledWith(
            '/fullPath-fork-new/-/merge_requests/new?merge_request%5Bissue_iid%5D=1&merge_request%5Bsource_branch%5D=suggested_branch_name%23with_hash&merge_request%5Btarget_branch%5D=master',
          );
        });
      });
    });
  });

  describe('when hosted at a relative root', () => {
    beforeEach(() => {
      gon.relative_url_root = '/gitlab';
      mock = new MockAdapter(axios);
      mock.onGet('gitlab/fullPath/-/issues/1/can_create_branch').reply(HTTP_STATUS_OK, {
        can_create_branch: true,
        suggested_branch_name: 'suggested_branch_name',
      });
      return createWrapper();
    });

    it('calls the create branch mutation with the correct parameters', async () => {
      createWrapper();
      await waitForPromises();

      jest.spyOn(axios, 'post');
      mock
        .onPost('/gitlab/fullPath/-/branches')
        .reply(HTTP_STATUS_OK, { data: { url: 'http://test.com/branch' } });

      firePrimaryEvent();
      await waitForPromises();

      expect(axios.post).toHaveBeenCalledWith(`/gitlab/fullPath/-/branches`, {
        branch_name: 'suggested_branch_name',
        confidential_issue_project_id: null,
        format: 'json',
        issue_iid: '1',
        ref: 'master',
      });
    });
  });
});
