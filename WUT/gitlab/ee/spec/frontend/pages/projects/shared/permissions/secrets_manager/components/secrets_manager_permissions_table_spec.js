import { GlTab, GlTable } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionsTable from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_table.vue';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from 'ee/pages/projects/shared/permissions/secrets_manager/constants';

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(PermissionsTable, {
      propsData: {
        items: [],
        permissionCategory: PERMISSION_CATEGORY_USER,
        ...props,
      },
    });
  };

  const findTab = () => wrapper.findComponent(GlTab);
  const findTable = () => wrapper.findComponent(GlTable);

  const userFields = [
    { key: 'user', label: 'User' },
    { key: 'user-role', label: 'Role' },
    { key: 'scope', label: 'Scope' },
    { key: 'expiration', label: 'Expiration' },
    { key: 'access-granted', label: 'Access granted' },
  ];
  const groupFields = [
    { key: 'group', label: 'Group' },
    { key: 'scope', label: 'Scope' },
    { key: 'expiration', label: 'Expiration' },
    { key: 'access-granted', label: 'Access granted' },
  ];
  const roleFields = [
    { key: 'role', label: 'Role' },
    { key: 'scope', label: 'Scope' },
    { key: 'expiration', label: 'Expiration' },
    { key: 'access-granted', label: 'Access granted' },
  ];

  describe.each`
    permissionCategory           | tableFields    | title
    ${PERMISSION_CATEGORY_USER}  | ${userFields}  | ${'Users'}
    ${PERMISSION_CATEGORY_GROUP} | ${groupFields} | ${'Group'}
    ${PERMISSION_CATEGORY_ROLE}  | ${roleFields}  | ${'Roles'}
  `('$permissionCategory table', ({ permissionCategory, tableFields, title }) => {
    beforeEach(() => {
      createComponent({ props: { permissionCategory } });
    });

    it('renders the correct title', () => {
      expect(findTab().attributes('title')).toBe(title);
    });

    it('renders the correct table fields', () => {
      expect(findTable().props('fields')).toMatchObject(tableFields);
    });
  });
});
