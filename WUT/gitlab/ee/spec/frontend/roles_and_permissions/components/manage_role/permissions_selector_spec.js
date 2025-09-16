import { GlTable, GlFormCheckbox, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import PermissionsSelector, {
  FIELDS,
} from 'ee/roles_and_permissions/components/manage_role/permissions_selector.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import memberPermissionsQuery from 'ee/roles_and_permissions/graphql/member_role_permissions.query.graphql';
import adminPermissionsQuery from 'ee/roles_and_permissions/graphql/admin_role/role_permissions.query.graphql';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { mockPermissionsResponse, mockDefaultPermissions } from '../../mock_data';

Vue.use(VueApollo);

describe('Permissions Selector component', () => {
  let wrapper;

  const defaultAvailablePermissionsHandler = jest.fn().mockResolvedValue(mockPermissionsResponse);
  const glTableStub = stubComponent(GlTable, { props: ['items', 'fields', 'busy'] });

  const createComponent = ({
    mountFn = shallowMountExtended,
    permissions = [],
    permissionsQuery = memberPermissionsQuery,
    isValid = true,
    selectedBaseRole = null,
    availablePermissionsHandler = defaultAvailablePermissionsHandler,
    isAdminRole = false,
  } = {}) => {
    wrapper = mountFn(PermissionsSelector, {
      propsData: { permissions, isValid, selectedBaseRole },
      provide: { isAdminRole },
      apolloProvider: createMockApollo([[permissionsQuery, availablePermissionsHandler]]),
      stubs: {
        GlSprintf,
        ...(mountFn === shallowMountExtended ? { GlTable: glTableStub } : {}),
        CrudComponent,
      },
    });

    return waitForPromises();
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findCheckboxes = () => wrapper.findAllByTestId('permission-checkbox');
  const findToggleAllCheckbox = () => wrapper.findByTestId('permission-checkbox-all');
  const findPermissionsSelectedMessage = () => wrapper.findByTestId('permissions-selected-message');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLearnMore = () => wrapper.findByTestId('learn-more');
  const findLearnMoreLink = () => findLearnMore().findComponent(GlLink);

  const checkPermission = (value) => {
    findTable().vm.$emit('row-clicked', { value });
  };

  const expectSelectedPermissions = (expected) => {
    const permissions = wrapper.emitted('change')[0][0];

    expect(permissions.sort()).toEqual(expected.sort());
  };

  describe('learn more description', () => {
    beforeEach(() => createComponent());

    it('shows text', () => {
      expect(findLearnMore().text()).toBe('Learn more about available custom permissions.');
    });

    it('shows link', () => {
      expect(findLearnMoreLink().text()).toBe('available custom permissions');
      expect(findLearnMoreLink().props()).toMatchObject({
        href: '/help/user/custom_roles/abilities',
        target: '_blank',
      });
    });
  });

  describe('available permissions', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('calls the query', () => {
        expect(defaultAvailablePermissionsHandler).toHaveBeenCalledTimes(1);
      });

      it('shows the table as busy', () => {
        expect(findTable().props('busy')).toBe(true);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });

      it('does not show the error message', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('after data is loaded', () => {
      beforeEach(() => {
        return createComponent();
      });

      it('shows the table with the expected permissions', () => {
        expect(findTable().props('busy')).toBe(false);
        expect(findTable().props()).toMatchObject({
          fields: FIELDS,
          items: mockDefaultPermissions,
        });
      });

      it('shows the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().text()).toBe('0 of 7 permissions selected');
      });

      it('does not show the error message', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('when base access role is selected', () => {
      beforeEach(() => {
        return createComponent({
          mountFn: mountExtended,
          selectedBaseRole: 'DEVELOPER',
        });
      });

      it('shows the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().text()).toBe('3 of 7 permissions selected');
      });

      it('disables the included permissions and adds a badge', () => {
        const notIncludedIndexes = [0, 1, 2, 3];
        const includedIndexes = [4, 5, 6];

        notIncludedIndexes.forEach((i) => {
          expect(findTableRowData(i).at(1).text()).not.toContain('Added from');
          expect(findCheckboxes().at(i).attributes('disabled')).toBeUndefined();
        });

        includedIndexes.forEach((i) => {
          expect(findTableRowData(i).at(1).text()).toContain('Added from Developer');
          expect(findCheckboxes().at(i).attributes('disabled')).toBeDefined();
        });
      });

      it('does not emit `change` event for included permissions when all permissions are selected', async () => {
        await findToggleAllCheckbox().trigger('change');

        expect(wrapper.emitted('change')[0][0]).toEqual(['A', 'B', 'C', 'D']);
      });
    });

    describe('when disabled permissions is clicked', () => {
      beforeEach(async () => {
        await createComponent();
        findTable().vm.$emit('row-clicked', { disabled: true });
      });

      it('does not toggle permission', () => {
        expect(wrapper.emitted('change')).toBeUndefined();
      });
    });

    describe('on query error', () => {
      beforeEach(() => {
        const availablePermissionsHandler = jest.fn().mockRejectedValue();
        return createComponent({ availablePermissionsHandler });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('Could not fetch available permissions.');
      });

      it('does not show the table', () => {
        expect(findTable().exists()).toBe(false);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });
    });
  });

  describe('dependent permissions', () => {
    it.each`
      permission | expected
      ${'A'}     | ${['A']}
      ${'B'}     | ${['A', 'B']}
      ${'C'}     | ${['A', 'B', 'C']}
      ${'D'}     | ${['A', 'B', 'C', 'D']}
      ${'E'}     | ${['E', 'F']}
      ${'F'}     | ${['E', 'F']}
      ${'G'}     | ${['A', 'B', 'C', 'G']}
    `('selects $expected when $permission is selected', async ({ permission, expected }) => {
      await createComponent();
      checkPermission(permission);

      expectSelectedPermissions(expected);
    });

    it.each`
      permission | expected
      ${'A'}     | ${['E', 'F']}
      ${'B'}     | ${['A', 'E', 'F']}
      ${'C'}     | ${['A', 'B', 'E', 'F']}
      ${'D'}     | ${['A', 'B', 'C', 'E', 'F', 'G']}
      ${'E'}     | ${['A', 'B', 'C', 'D', 'G']}
      ${'F'}     | ${['A', 'B', 'C', 'D', 'G']}
      ${'G'}     | ${['A', 'B', 'C', 'D', 'E', 'F']}
    `(
      'selects $expected when all permissions start off selected and $permission is unselected',
      async ({ permission, expected }) => {
        const permissions = mockDefaultPermissions.map((p) => p.value);
        await createComponent({ permissions });
        // Uncheck the permission by removing it from all permissions.
        checkPermission(permission);

        expectSelectedPermissions(expected);
      },
    );

    it('checks the permission when the table row is clicked', async () => {
      await createComponent({ mountFn: mountExtended });
      findTable().find('tbody tr').trigger('click');

      expectSelectedPermissions(['A']);
    });

    it('checks the permission when the checkbox is clicked', async () => {
      await createComponent({ mountFn: mountExtended });
      wrapper.findAllComponents(GlFormCheckbox).at(1).trigger('click');

      expectSelectedPermissions(['A']);
    });
  });

  describe('validation state', () => {
    it.each([true, false])('shows the expected text when isValid prop is %s', async (isValid) => {
      await createComponent({ mountFn: mountExtended, isValid });

      expect(wrapper.find('tbody td span').classes('gl-text-danger')).toBe(!isValid);
    });
  });

  describe('for admin role', () => {
    beforeEach(() =>
      createComponent({ isAdminRole: true, permissionsQuery: adminPermissionsQuery }),
    );

    it('calls the admin permissions query', () => {
      expect(defaultAvailablePermissionsHandler).toHaveBeenCalledTimes(1);
    });

    it('does not show learn more description', () => {
      expect(findLearnMore().exists()).toBe(false);
    });
  });
});
