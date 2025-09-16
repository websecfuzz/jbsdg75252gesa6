import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import UserTypeSelector from 'ee/admin/users/components/user_type/user_type_selector.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initUserTypeSelector = () => {
  const el = document.getElementById('js-user-type');
  if (!el) return null;

  const {
    userType,
    isCurrentUser,
    licenseAllowsAuditorUser,
    adminRole = null,
    manageRolesPath,
  } = el.dataset;

  return new Vue({
    el,
    name: 'UserTypeSelectorRoot',
    apolloProvider,
    provide: { manageRolesPath },
    render(createElement) {
      return createElement(UserTypeSelector, {
        props: {
          userType,
          isCurrentUser: parseBoolean(isCurrentUser),
          licenseAllowsAuditorUser: parseBoolean(licenseAllowsAuditorUser),
          adminRole: JSON.parse(adminRole),
        },
      });
    },
  });
};
