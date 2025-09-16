<script>
import { GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-catalog-md.svg';
import AiCatalogListItem from './ai_catalog_list_item.vue';

export default {
  name: 'AiCatalogList',
  components: {
    AiCatalogListItem,
    GlEmptyState,
    GlSkeletonLoader,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  EMPTY_SVG_URL,
};
</script>

<template>
  <div data-testid="ai-catalog-list">
    <gl-skeleton-loader v-if="isLoading" :lines="2" />

    <ul v-else-if="items.length > 0" class="gl-list-style-none gl-m-0 gl-p-0">
      <ai-catalog-list-item v-for="item in items" :key="item.id" :item="item" />
    </ul>

    <gl-empty-state
      v-else
      :title="s__('AICatalog|Get started with the AI Catalog')"
      :description="
        s__('AICatalog|Build AI agents and flows to automate repetitive tasks and processes.')
      "
      :svg-path="$options.EMPTY_SVG_URL"
    />
  </div>
</template>
