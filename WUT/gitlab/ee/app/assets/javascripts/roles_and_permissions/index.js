import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { InternalEvents } from '~/tracking';
import RoleTabs from './components/role_tabs.vue';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCustomRolesApp = () => {
  const el = document.querySelector('#js-roles-and-permissions');

  if (!el) {
    return null;
  }

  const {
    groupFullPath,
    groupId,
    newRolePath,
    currentUserEmail,
    ldapUsersPath,
    ldapServers = null,
  } = el.dataset;

  return new Vue({
    el,
    name: 'RolesRoot',
    apolloProvider,
    mixins: [InternalEvents.mixin()],
    provide: {
      groupId,
      currentUserEmail,
      groupFullPath,
      newRolePath,
      ldapUsersPath,
      ldapServers: JSON.parse(ldapServers),
    },
    mounted() {
      this.trackEvent('view_admin_application_settings_roles_and_permissions_pageload');
    },
    render(createElement) {
      return createElement(RoleTabs);
    },
  });
};
