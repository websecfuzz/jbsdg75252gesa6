import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK, HTTP_STATUS_UNPROCESSABLE_ENTITY } from '~/lib/utils/http_status';
import * as urlUtility from '~/lib/utils/url_utility';
import CommitChangesModal from '~/repository/components/commit_changes_modal.vue';
import NewDirectoryModal from '~/repository/components/new_directory_modal.vue';

jest.mock('~/alert');
jest.mock('~/lib/logger');

const initialProps = {
  modalTitle: 'Create new directory',
  modalId: 'modal-new-directory',
  commitMessage: 'Add new directory',
  targetBranch: 'some-target-branch',
  originalBranch: 'main',
  canPushCode: true,
  canPushToBranch: true,
  path: 'create_dir',
};

const defaultFormValue = {
  dirName: 'foo',
  originalBranch: initialProps.originalBranch,
  targetBranch: initialProps.targetBranch,
  commitMessage: initialProps.commitMessage,
  createNewMr: true,
};

describe('NewDirectoryModal', () => {
  let wrapper;
  let mock;
  let visitUrlSpy;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(NewDirectoryModal, {
      propsData: {
        ...initialProps,
        ...props,
      },
      attrs: {
        static: true,
        visible: true,
      },
      stubs: {
        CommitChangesModal,
      },
    });
  };

  const findCommitChangesModal = () => wrapper.findComponent(CommitChangesModal);
  const findDirName = () => wrapper.find('[name="dir_name"]');
  const fillForm = async (dirName = defaultFormValue.dirName) => {
    await findDirName().vm.$emit('input', dirName);
    await nextTick();
  };

  const submitForm = async ({ branchName } = {}) => {
    const formData = new FormData();
    if (branchName) {
      formData.append('branch_name', branchName);
    }
    findCommitChangesModal().vm.$emit('submit-form', formData);
    await waitForPromises();
  };

  beforeEach(() => {
    visitUrlSpy = jest.spyOn(urlUtility, 'visitUrl');
    createComponent();
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders commit changes modal', () => {
      expect(findCommitChangesModal().props()).toMatchObject({
        modalId: 'modal-new-directory',
        commitMessage: 'Add new directory',
        targetBranch: 'some-target-branch',
        originalBranch: 'main',
        canPushCode: true,
        canPushToBranch: true,
        valid: false,
        loading: false,
      });
    });

    it('includes directory name input', () => {
      expect(findDirName().exists()).toBe(true);
    });
  });

  describe('form submission', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('valid form', () => {
      it('enables submit button when form is complete', async () => {
        await fillForm({ dirName: 'test-dir' });
        expect(findCommitChangesModal().props('valid')).toBe(true);
      });

      describe('passes additional formData', () => {
        it('passes original branch name as branch name if branch name does not exist on formData', async () => {
          const { dirName, originalBranch } = defaultFormValue;
          mock.onPost(initialProps.path).reply(HTTP_STATUS_OK, {});
          await fillForm();
          await submitForm();

          const formData = mock.history.post[0].data;
          expect(formData.get('dir_name')).toBe(dirName);
          expect(formData.get('branch_name')).toBe(originalBranch);
        });

        it('passes target branch name as branch name if branch name does exist on formData', async () => {
          const { dirName, targetBranch } = defaultFormValue;
          mock.onPost(initialProps.path).reply(HTTP_STATUS_OK, {});
          await fillForm();
          await submitForm({ branchName: targetBranch });

          const formData = mock.history.post[0].data;
          expect(formData.get('dir_name')).toBe(dirName);
          expect(formData.get('branch_name')).toBe(targetBranch);
        });
      });

      it('redirects to the new directory', async () => {
        const response = { filePath: 'new-dir-path' };
        mock.onPost(initialProps.path).reply(HTTP_STATUS_OK, response);

        await fillForm('foo');
        await submitForm();

        expect(visitUrlSpy).toHaveBeenCalledWith(response.filePath);
      });
    });

    describe('invalid form', () => {
      it('passes correct prop for validity', async () => {
        await fillForm('');
        expect(findCommitChangesModal().props('valid')).toBe(false);
      });

      describe('error handling', () => {
        const errorMessage = 'Custom error message';

        const submitWithError = async () => {
          mock
            .onPost('/create_dir')
            .replyOnce(HTTP_STATUS_UNPROCESSABLE_ENTITY, { error: errorMessage });
          await fillForm('foo');
          return submitForm();
        };

        beforeEach(() => submitWithError());

        it('shows error message in modal when request fails', () => {
          expect(findCommitChangesModal().props('error')).toBe(errorMessage);
        });

        it('clears error on successful submission', async () => {
          await submitForm();

          expect(findCommitChangesModal().props('error')).toBeNull();
        });
      });
    });
  });
});
