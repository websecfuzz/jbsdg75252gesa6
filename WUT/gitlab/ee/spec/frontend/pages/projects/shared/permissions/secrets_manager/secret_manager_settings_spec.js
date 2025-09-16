import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import SecretManagerSettings, {
  POLL_INTERVAL,
} from 'ee/pages/projects/shared/permissions/secrets_manager/secrets_manager_settings.vue';
import {
  initializeSecretManagerSettingsResponse,
  secretManagerSettingsResponse,
} from './mock_data';

Vue.use(VueApollo);
const showToast = jest.fn();

describe('SecretManagerSettings', () => {
  let wrapper;
  let mockEnableSecretManager;
  let mockSecretManagerStatus;

  const activeResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_ACTIVE);
  const provisioningResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_PROVISIONING);
  // secrets manager has not been provisioned yet, so status would be NULL when it's inactive
  const inactiveResponse = secretManagerSettingsResponse(null);
  const fullPath = 'gitlab-org/gitlab';

  const createComponent = async ({ props } = {}) => {
    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [enableSecretManagerMutation, mockEnableSecretManager],
    ];
    const mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(SecretManagerSettings, {
      apolloProvider: mockApollo,
      propsData: {
        canManageSecretsManager: true,
        fullPath,
        ...props,
      },
      mocks: {
        $toast: {
          show: showToast,
        },
      },
    });

    await waitForPromises();
    await nextTick();
  };

  const findError = () => wrapper.findByTestId('secret-manager-error');
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findPermissionsSettings = () => wrapper.findComponent(PermissionsSettings);

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const toggleSetting = async (errors = []) => {
    const mutationResponse = initializeSecretManagerSettingsResponse(errors);
    mockEnableSecretManager.mockResolvedValue(mutationResponse);

    findToggle().vm.$emit('change', true);
    await waitForPromises();
  };

  const pollNextStatus = async (queryResponse) => {
    mockSecretManagerStatus.mockResolvedValue(queryResponse);
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockEnableSecretManager = jest.fn();
    mockSecretManagerStatus = jest.fn();
  });

  describe('template', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
      await createComponent({ props: { canManageSecretsManager: false } });
    });

    it('disables toggle when user does not have permission', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });
  });

  describe('when query is loading', () => {
    it('disables toggle and shows loading state', () => {
      createComponent();

      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('isLoading')).toBe(true);
    });
  });

  describe('when query receives ACTIVE status', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(activeResponse);
      await createComponent();
    });

    it('disables toggle and shows active state', () => {
      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('value')).toBe(true);
    });

    it('renders permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(true);
    });
  });

  describe('when query receives PROVISIONING status', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(provisioningResponse);
      await createComponent();
    });

    it('disables toggle and shows loading state', () => {
      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('does not render permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe('when query receives NULL status', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
      await createComponent();
    });

    it('shows inactive state', () => {
      expect(findToggle().props('disabled')).toBe(false);
      expect(findToggle().props('value')).toBe(false);
    });

    it('does not render permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe('when enabling the secrets manager', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
      await createComponent();
    });

    it('sends mutation request', async () => {
      await toggleSetting();

      expect(mockEnableSecretManager).toHaveBeenCalledWith({
        projectPath: fullPath,
      });
    });

    it('shows error message on failure', async () => {
      await toggleSetting(['Error encountered']);

      expect(findError().exists()).toBe(true);
    });

    it('starts polling for a new status while status is PROVISIONING', async () => {
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

      await toggleSetting();
      await pollNextStatus(provisioningResponse);
      await pollNextStatus(provisioningResponse);
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(3);
    });

    it('stops polling for status when new status is ACTIVE', async () => {
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

      await toggleSetting();
      await pollNextStatus(activeResponse);
      await pollNextStatus(activeResponse);

      expect(findToggle().props('value')).toBe(true);
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
    });

    it('shows toast message on success', async () => {
      await toggleSetting();
      await pollNextStatus(activeResponse);

      expect(showToast).toHaveBeenCalledWith(
        'Secrets Manager has been provisioned for this project.',
      );
    });
  });
});
