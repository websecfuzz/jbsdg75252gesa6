import { GlModal, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import DuoWorkflowSettings from 'ee/ai/settings/components/duo_workflow_settings.vue';
import axios from '~/lib/utils/axios_utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils');
jest.mock('~/lib/utils/url_utility');

describe('DuoWorkflowSettings', () => {
  let wrapper;

  const SERVICE_ACCOUNT = {
    id: 1,
    name: 'GitLab Duo',
    username: 'gitlab-duo',
    avatarUrl: '/avatar.png',
    webUrl: '/gitlab-duo',
  };

  const WORKFLOW_SETTINGS_PATH = '/admin/ai/duo_workflow_settings';
  const WORKFLOW_DISABLE_PATH = '/admin/ai/duo_workflow_settings/disconnect';
  const REDIRECT_PATH = '/admin/gitlab_duo';

  const findEnableButton = () => wrapper.findByTestId('enable-workflow-button');
  const findDisableButton = () => wrapper.findByTestId('disable-workflow-button');
  const findConfirmModal = () => wrapper.findComponent(GlModal);
  const findWorkflowStatus = () => wrapper.find('h3');
  const findTitle = () => wrapper.findByTestId('duo-workflow-settings-title');
  const findSubtitle = () => wrapper.findByTestId('duo-workflow-settings-subtitle');
  const findServiceAccount = () => wrapper.findByTestId('service-account');
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createWrapper = (provide = {}) => {
    const defaultMountOptions = {
      propsData: {
        title: 'Test Title',
        subtitle: 'Test Subtitle',
      },
      provide: {
        duoWorkflowEnabled: false,
        duoWorkflowServiceAccount: null,
        duoWorkflowSettingsPath: WORKFLOW_SETTINGS_PATH,
        duoWorkflowDisablePath: WORKFLOW_DISABLE_PATH,
        redirectPath: REDIRECT_PATH,
        ...provide,
      },
      stubs: {
        GlModal: true,
      },
    };

    wrapper = shallowMountExtended(DuoWorkflowSettings, defaultMountOptions);
  };

  beforeEach(() => {
    jest.clearAllMocks();

    axios.post = jest.fn().mockResolvedValue({ status: 200 });
    visitUrlWithAlerts.mockImplementation(() => {});
  });

  describe('component rendering', () => {
    it('renders the component with default props when workflow is disabled', () => {
      createWrapper();

      expect(findTitle().text()).toBe('Test Title');
      expect(findSubtitle().text()).toBe('Test Subtitle');
      expect(findEnableButton().exists()).toBe(true);
      expect(findDisableButton().exists()).toBe(false);
      expect(findWorkflowStatus().text()).toBe('Off');
    });

    it('renders the component when workflow is enabled', () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });

      expect(findEnableButton().exists()).toBe(false);
      expect(findDisableButton().exists()).toBe(true);
      expect(findWorkflowStatus().text()).toContain('On');
      expect(findServiceAccount().text()).toContain(SERVICE_ACCOUNT.name);
      expect(findServiceAccount().text()).toContain(SERVICE_ACCOUNT.username);
    });
  });

  describe('workflow operations', () => {
    describe('enabling GitLab Duo Workflow', () => {
      it('shows success message with new service account when created', async () => {
        createWrapper();

        axios.post.mockResolvedValueOnce({
          status: 200,
          data: {
            service_account: SERVICE_ACCOUNT,
          },
        });

        findEnableButton().vm.$emit('click');

        expect(axios.post).toHaveBeenCalledWith(WORKFLOW_SETTINGS_PATH);

        await waitForPromises();

        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          REDIRECT_PATH,
          expect.arrayContaining([
            expect.objectContaining({
              id: 'duo-workflow-successfully-enabled',
              message: `GitLab Duo Workflow is now on for the instance and the service account (@${SERVICE_ACCOUNT.username}) was created. To use Workflow in your groups, you must turn on AI features for specific groups.`,
              variant: 'success',
            }),
          ]),
        );
      });

      it('shows generic success message when no service account info is available', async () => {
        createWrapper();

        axios.post.mockResolvedValueOnce({
          status: 200,
          data: {},
        });

        findEnableButton().vm.$emit('click');

        await waitForPromises();

        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          REDIRECT_PATH,
          expect.arrayContaining([
            expect.objectContaining({
              id: 'duo-workflow-successfully-enabled',
              message:
                'GitLab Duo Workflow is now on for the instance. To use Workflow in your groups, you must turn on AI features for specific groups.',
              variant: 'success',
            }),
          ]),
        );
      });
    });

    it('calls the disable workflow API and redirects with success alert', async () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });

      findConfirmModal().vm.$emit('primary');

      expect(axios.post).toHaveBeenCalledWith(WORKFLOW_DISABLE_PATH);

      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        REDIRECT_PATH,
        expect.arrayContaining([
          expect.objectContaining({
            id: 'duo-workflow-successfully-disabled',
            message: 'GitLab Duo Workflow has successfully been turned off.',
            variant: 'success',
          }),
        ]),
      );
    });

    it('shows disable button when workflow is enabled', () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });
      expect(findDisableButton().text()).toContain('Turn off GitLab Duo Workflow');
    });

    it('clicking disable button shows the confirmation modal', async () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });

      expect(findConfirmModal().props('visible')).toBe(false);

      findDisableButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(true);
    });
  });

  describe('modal interactions', () => {
    it('shows and hides the confirmation modal', async () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });

      expect(findConfirmModal().props('visible')).toBe(false);

      findDisableButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(true);

      findConfirmModal().vm.$emit('cancel');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('handles enable workflow error', async () => {
      createWrapper();
      const error = new Error('API Error');
      axios.post.mockRejectedValueOnce(error);

      findEnableButton().vm.$emit('click');
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises().catch(() => {});

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringContaining('Failed to enable'),
          error,
        }),
      );
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    it('handles disable workflow error', async () => {
      createWrapper({
        duoWorkflowEnabled: true,
        duoWorkflowServiceAccount: SERVICE_ACCOUNT,
      });
      const error = new Error('API Error');
      axios.post.mockRejectedValueOnce(error);

      findConfirmModal().vm.$emit('primary');
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises().catch(() => {});

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringContaining('Failed to disable'),
          error,
        }),
      );
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });
});
