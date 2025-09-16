import { GlLink, GlSprintf, GlTabs, GlTab } from '@gitlab/ui';
import RoleTabs from 'ee/roles_and_permissions/components/role_tabs.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import RolesCrud from 'ee/roles_and_permissions/components/roles_table/roles_crud.vue';
import LdapSyncCrud from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_crud.vue';
import { ldapServers as ldapServersData } from '../mock_data';

describe('RoleTabs component', () => {
  let wrapper;

  const createWrapper = ({ ldapServers = ldapServersData, customAdminRoles = true } = {}) => {
    wrapper = shallowMountExtended(RoleTabs, {
      provide: {
        ldapServers,
        glFeatures: { customAdminRoles },
      },
      stubs: { GlSprintf },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findDocsLink = () => findPageHeading().findComponent(GlLink);
  const findRolesCrud = () => wrapper.findComponent(RolesCrud);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findTabAt = (index) => wrapper.findAllComponents(GlTab).at(index);
  const findLdapSyncCrud = () => wrapper.findComponent(LdapSyncCrud);

  describe('page heading', () => {
    beforeEach(() => createWrapper());

    it('shows heading', () => {
      expect(findPageHeading().props('heading')).toBe('Roles and permissions');
    });

    it('shows description', () => {
      expect(findPageHeading().text()).toBe(
        'Manage which actions users can take with roles and permissions.',
      );
    });

    it('shows docs page link', () => {
      expect(findDocsLink().text()).toBe('roles and permissions');
      expect(findDocsLink().attributes()).toMatchObject({
        href: '/help/user/permissions',
        target: '_blank',
      });
    });
  });

  describe.each`
    phrase                                                | options
    ${'when ldap is disabled'}                            | ${{ ldapServers: null }}
    ${'when custom admin roles feature flag is disabled'} | ${{ customAdminRoles: false }}
  `('$phrase', ({ options }) => {
    beforeEach(() => createWrapper(options));

    it('shows roles crud', () => {
      expect(findRolesCrud().exists()).toBe(true);
    });

    it('does not show tabs', () => {
      expect(findTabs().exists()).toBe(false);
    });

    it('does not show ldap sync crud', () => {
      expect(findLdapSyncCrud().exists()).toBe(false);
    });
  });

  describe('when ldap is enabled', () => {
    beforeEach(() => createWrapper());

    it('shows tabs', () => {
      expect(findTabs().props('syncActiveTabWithQueryParams')).toBe(true);
    });

    it('shows roles tab', () => {
      expect(findTabAt(0).attributes('title')).toBe('Roles');
      expect(findTabAt(0).props('queryParamValue')).toBe('roles');
    });

    it('shows ldap tab', () => {
      expect(findTabAt(1).attributes('title')).toBe('LDAP Synchronization');
      expect(findTabAt(1).props('queryParamValue')).toBe('ldap');
    });

    it('shows roles crud in roles tab', () => {
      expect(findTabAt(0).findComponent(RolesCrud).exists()).toBe(true);
    });

    it('shows ldap sync crud in ldap tab', () => {
      expect(findTabAt(1).findComponent(LdapSyncCrud).exists()).toBe(true);
    });
  });
});
