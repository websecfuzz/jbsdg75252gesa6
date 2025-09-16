import { GlTable, GlLoadingIcon, GlLink, GlBadge } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RolesTable, {
  TABLE_FIELDS,
} from 'ee/roles_and_permissions/components/roles_table/roles_table.vue';
import RoleActions from 'ee/roles_and_permissions/components/roles_table/role_actions.vue';
import { stubComponent } from 'helpers/stub_component';
import { standardRoles, memberRoles, adminRoles } from '../../mock_data';

describe('Roles table', () => {
  let wrapper;
  const roles = [...standardRoles, ...memberRoles, ...adminRoles];

  const createComponent = ({ busy = false, stubs } = {}) => {
    wrapper = mountExtended(RolesTable, {
      propsData: { roles, busy },
      stubs,
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableLoadingIcon = () => findTable().findComponent(GlLoadingIcon);
  const findRowCell = ({ row, cell }) => wrapper.findAll('tbody tr').at(row).findAll('td').at(cell);
  const findRoleCell = (role, cell) => findRowCell({ row: roles.indexOf(role), cell });
  const findCustomRoleBadge = (role) => findRoleCell(role, 0).findComponent(GlBadge);
  const findRoleActions = (role) => findRoleCell(role, 3).findComponent(RoleActions);

  describe('roles table', () => {
    beforeEach(() =>
      createComponent({
        stubs: { GlTable: stubComponent(GlTable, { props: ['fields', 'items'] }) },
      }),
    );

    it('shows table fields', () => {
      expect(findTable().props('fields')).toBe(TABLE_FIELDS);
    });

    it('shows items', () => {
      expect(findTable().props('items')).toBe(roles);
    });
  });

  describe('table busy state', () => {
    it('shows loading icon when table is busy', () => {
      createComponent({ busy: true });

      expect(findTableLoadingIcon().props('size')).toBe('md');
    });

    it('does not show loading icon when table is not busy', () => {
      createComponent({ busy: false });

      expect(findTableLoadingIcon().exists()).toBe(false);
    });
  });

  describe.each(roles)('for $name role', (role) => {
    beforeEach(() => createComponent());

    it('shows role name', () => {
      const link = findRoleCell(role, 0).findComponent(GlLink);

      expect(link.text()).toBe(role.name);
      expect(link.attributes('href')).toBe(role.detailsPath);
    });

    it('shows description', () => {
      expect(findRoleCell(role, 1).text()).toBe(role.description);
    });

    it('shows role actions', () => {
      expect(findRoleActions(role).props('role')).toBe(role);
    });

    it('emits delete-role event when role actions emits delete event', () => {
      findRoleActions(role).vm.$emit('delete');

      expect(wrapper.emitted('delete-role')).toHaveLength(1);
      expect(wrapper.emitted('delete-role')[0][0]).toBe(role);
    });
  });

  describe.each(standardRoles)('for default role $name', (role) => {
    beforeEach(() => createComponent());

    it('does not show custom role badge', () => {
      expect(findCustomRoleBadge(role).exists()).toBe(false);
    });
  });

  describe.each(memberRoles)('for custom role $name', (role) => {
    beforeEach(() => createComponent());

    it('shows custom role badge', () => {
      expect(findCustomRoleBadge(role).text()).toBe('Custom member role');
    });
  });

  describe.each(adminRoles)('for admin role $name', (role) => {
    beforeEach(() => createComponent());

    it('shows admin role badge', () => {
      const badge = findCustomRoleBadge(role);
      expect(badge.text()).toBe('Custom admin role');
      expect(badge.props()).toMatchObject({
        icon: 'admin',
        variant: 'info',
      });
    });
  });
});
