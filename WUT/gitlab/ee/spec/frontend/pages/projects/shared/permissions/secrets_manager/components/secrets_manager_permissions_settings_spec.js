import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;

  const createComponent = ({ props, canManageSecretsManager = true } = {}) => {
    wrapper = shallowMountExtended(PermissionsSettings, {
      propsData: {
        canManageSecretsManager,
        fullPath: '/path/to/project',
        ...props,
      },
    });
  };

  const findActionsDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPermissionsTable = (index) => wrapper.findAllComponents(PermissionsTable).at(index);

  describe('template', () => {
    it('renders permissions tables', () => {
      createComponent();

      expect(findPermissionsTable(0).props('permissionCategory')).toBe('user');
      expect(findPermissionsTable(1).props('permissionCategory')).toBe('group');
      expect(findPermissionsTable(2).props('permissionCategory')).toBe('role');
    });

    it('renders actions dropdown when user has permissions', () => {
      createComponent();

      expect(findActionsDropdown().exists()).toBe(true);
    });

    it("does not render actions dropdown when user doesn't have permission", () => {
      createComponent({ canManageSecretsManager: false });

      expect(findActionsDropdown().exists()).toBe(false);
    });
  });
});
