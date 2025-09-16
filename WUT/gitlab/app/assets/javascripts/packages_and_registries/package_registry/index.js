import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import { parseBoolean } from '~/lib/utils/common_utils';
import { apolloProvider } from '~/packages_and_registries/package_registry/graphql/index';
import PackageRegistry from '~/packages_and_registries/package_registry/pages/index.vue';
import RegistryBreadcrumb from '~/packages_and_registries/shared/components/registry_breadcrumb.vue';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import createRouter from './router';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-vue-packages-list');
  const {
    endpoint,
    fullPath,
    pageType,
    emptyListIllustration,
    npmInstanceUrl,
    npmGroupUrl,
    projectListUrl,
    groupListUrl,
    settingsPath,
    canDeletePackages,
  } = el.dataset;

  const isGroupPage = pageType === 'groups';

  const router = createRouter(endpoint);

  const attachMainComponent = () =>
    new Vue({
      el,
      name: 'PackageRegistry',
      router,
      apolloProvider,
      provide: {
        fullPath,
        emptyListIllustration,
        isGroupPage,
        npmInstanceUrl,
        npmGroupUrl,
        projectListUrl,
        groupListUrl,
        settingsPath,
        canDeletePackages: parseBoolean(canDeletePackages),
      },
      render(createElement) {
        return createElement(PackageRegistry);
      },
    });

  return {
    attachBreadcrumb: () => injectVueAppBreadcrumbs(router, RegistryBreadcrumb, apolloProvider),
    attachMainComponent,
  };
};
