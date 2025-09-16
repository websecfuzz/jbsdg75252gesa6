<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTS_PLATFORM_NEW_ROUTE,
} from './constants';

export default {
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
  },
  computed: {
    rootRoutes() {
      return [
        {
          text: s__('DuoAgentsPlatform|Automate'),
          to: { name: AGENTS_PLATFORM_INDEX_ROUTE },
        },
        {
          text: s__('DuoAgentsPlatform|Agent sessions'),
          to: { name: AGENTS_PLATFORM_INDEX_ROUTE },
        },
      ];
    },
    showRoute() {
      return {
        text: String(this.$route.params.id),
        to: { name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: this.$route.params.id } },
      };
    },
    isIndexRoute() {
      return this.$route.name === AGENTS_PLATFORM_INDEX_ROUTE;
    },
    isShowRoute() {
      return this.$route.name === AGENTS_PLATFORM_SHOW_ROUTE;
    },
    isNewRoute() {
      return this.$route.name === AGENTS_PLATFORM_NEW_ROUTE;
    },
    crumbs() {
      const crumbs = [...this.staticBreadcrumbs];

      // add root route if not on index page
      if (!this.isIndexRoute) {
        this.rootRoutes.forEach((route) => crumbs.push(route));
      }

      // add agent details if route contains an agent id
      if (this.$route.params.id && this.isShowRoute) {
        crumbs.push({
          text: this.showRoute.text,
          to: undefined, // current page, no link
        });
      }

      if (this.isNewRoute) {
        crumbs.push({
          text: s__('DuoAgentsPlatform|New'),
          to: undefined, // current page, no link
        });
      }

      // if on index page, add current page without link
      if (this.isIndexRoute) {
        crumbs.push(this.rootRoutes[0]);
        crumbs.push({
          text: s__('DuoAgentsPlatform|Agent sessions'),
          to: undefined,
        });
      }

      return crumbs;
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
